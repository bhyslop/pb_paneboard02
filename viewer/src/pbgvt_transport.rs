// pbgvt — transport: the localhost-TCP wire, the port-file discovery channel,
// and the reference pusher client.
//
// Wire framing (FROZEN — the contract is the "Diagram Viewer — Wire Protocol"
// section of poc/paneboard-poc.md; this code is its reference implementation):
//   one JSON control line terminated by '\n', then exactly `pbgvw_len` payload
//   bytes, then — only when `pbgvw_dark_len` is present and non-zero — exactly
//   `pbgvw_dark_len` further bytes (the dark variant). Control keys and the verb
//   enum carry the `pbgvw_` sprue — one sprue per wire format, so `grep pbgvw_`
//   is the whole census:
//   { "pbgvw_verb": "pbgvw_fresh" | "pbgvw_update", "pbgvw_id": <u64>,
//     "pbgvw_len": <usize>, "pbgvw_dark_len": <usize>? }
// `pbgvw_dark_len` is the additive 2026-06-23 pair revision: absent or 0 ⇒ a
// single-payload frame, byte-identical to the prior contract. A connection may
// carry one frame or many, back to back. Each payload is self-describing
// (content-sniffed: SVG vs raster), never an out-of-band tag; the pair is joined
// positionally within the frame, never by `pbgvw_id`. The operator-facing CLI
// verb (`push fresh|update`) is a plain ashlar; the pusher maps it to the sprued
// wire value.
//
// Discovery: the viewer binds an ephemeral port and writes it to a fixed
// port-file under ~/.config/paneboard/ (paneboard's per-user config home).
// Pushers read that file to find the listener. The walking skeleton is a single
// viewer instance, so one port-file suffices; per-`pbgvw_id` viewer instances
// are a later conductor concern that would key the file by id.

use std::io::{BufRead, BufReader, Read, Write};
use std::net::{TcpListener, TcpStream};
use std::path::{Path, PathBuf};
use std::sync::mpsc::Sender;

use eframe::egui;
use serde::Deserialize;

use crate::pbgvd_decode::{self, Decoded};

#[derive(Clone, Copy)]
pub enum Verb {
    /// Open/replace: fit-to-window, default view.
    Fresh,
    /// Replace content while retaining the held zoom + pan (re-rasterized, so
    /// SVG stays crisp; raster is native-limited).
    Update,
}

/// One received, decoded frame, handed to the UI thread over the channel.
/// `dark` is the optional second variant of the light/dark pair — `None` for a
/// single-payload frame (the dark-toggle then falls back to `decoded`).
pub struct Frame {
    pub verb: Verb,
    pub id: u64,
    pub decoded: Decoded,
    pub dark: Option<Decoded>,
}

#[derive(Deserialize)]
struct Control {
    #[serde(rename = "pbgvw_verb")]
    verb: String,
    #[serde(rename = "pbgvw_id", default)]
    id: u64,
    #[serde(rename = "pbgvw_len")]
    len: usize,
    /// Optional dark-variant byte count (the additive pair revision). Absent or
    /// 0 ⇒ no dark payload follows.
    #[serde(rename = "pbgvw_dark_len", default)]
    dark_len: usize,
}

/// The fixed discovery path: `~/.config/paneboard/viewer.port`.
pub fn port_file() -> Option<PathBuf> {
    dirs::home_dir().map(|h| h.join(".config/paneboard/viewer.port"))
}

/// Bind an ephemeral localhost port, publish it to the port-file, and spawn the
/// accept loop. Returns the bound port (for display). Frames flow to `tx`; each
/// arrival wakes the UI via `ctx.request_repaint()`.
pub fn serve(ctx: egui::Context, tx: Sender<Frame>) -> std::io::Result<u16> {
    let listener = TcpListener::bind(("127.0.0.1", 0))?;
    let port = listener.local_addr()?.port();
    write_port_file(port);

    std::thread::spawn(move || {
        for stream in listener.incoming() {
            match stream {
                Ok(s) => {
                    let tx = tx.clone();
                    let ctx = ctx.clone();
                    std::thread::spawn(move || handle_conn(s, tx, ctx));
                }
                Err(e) => eprintln!("accept error: {e}"),
            }
        }
    });

    Ok(port)
}

fn write_port_file(port: u16) {
    let Some(path) = port_file() else {
        eprintln!("cannot resolve home dir for port-file");
        return;
    };
    if let Some(parent) = path.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    // Atomic publish: write a sibling temp, then rename over the real path.
    let tmp = path.with_extension("port.tmp");
    match std::fs::write(&tmp, port.to_string()) {
        Ok(()) => {
            if let Err(e) = std::fs::rename(&tmp, &path) {
                eprintln!("port-file rename failed: {e}");
            }
        }
        Err(e) => eprintln!("port-file write failed: {e}"),
    }
    eprintln!(
        "viewer listening on 127.0.0.1:{port}, port-file {}",
        path.display()
    );
}

fn handle_conn(stream: TcpStream, tx: Sender<Frame>, ctx: egui::Context) {
    let mut reader = BufReader::new(stream);
    loop {
        let mut line = Vec::new();
        match reader.read_until(b'\n', &mut line) {
            Ok(0) => break, // clean EOF
            Ok(_) => {}
            Err(e) => {
                eprintln!("control read error: {e}");
                break;
            }
        }
        while matches!(line.last(), Some(b'\n') | Some(b'\r')) {
            line.pop();
        }
        if line.is_empty() {
            continue;
        }

        let ctrl: Control = match serde_json::from_slice(&line) {
            Ok(c) => c,
            Err(e) => {
                eprintln!("bad control line: {e}");
                break;
            }
        };
        let verb = match ctrl.verb.as_str() {
            "pbgvw_fresh" => Verb::Fresh,
            "pbgvw_update" => Verb::Update,
            other => {
                eprintln!("unknown pbgvw_verb: {other}");
                break;
            }
        };

        let mut payload = vec![0u8; ctrl.len];
        if let Err(e) = reader.read_exact(&mut payload) {
            eprintln!("payload read error ({} bytes): {e}", ctrl.len);
            break;
        }

        // The optional dark variant. Consume its bytes off the wire FIRST, so a
        // later decode failure cannot desync framing for the next frame.
        let dark_payload = if ctrl.dark_len > 0 {
            let mut d = vec![0u8; ctrl.dark_len];
            if let Err(e) = reader.read_exact(&mut d) {
                eprintln!("dark payload read error ({} bytes): {e}", ctrl.dark_len);
                break;
            }
            Some(d)
        } else {
            None
        };

        let decoded = match pbgvd_decode::sniff_and_decode(payload) {
            Ok(d) => d,
            Err(e) => {
                // Framing is intact (both payloads already consumed); skip just
                // this frame and keep the connection for the next.
                eprintln!("decode error: {e}");
                continue;
            }
        };
        // A dark variant that fails to decode falls back to light-only — never
        // drop the whole frame for a bad second payload.
        let dark = dark_payload.and_then(|d| match pbgvd_decode::sniff_and_decode(d) {
            Ok(d) => Some(d),
            Err(e) => {
                eprintln!("dark decode error (light kept): {e}");
                None
            }
        });

        if tx
            .send(Frame {
                verb,
                id: ctrl.id,
                decoded,
                dark,
            })
            .is_err()
        {
            break; // UI gone
        }
        ctx.request_repaint();
    }
}

/// Reference pusher: read the port-file, connect, and send one framed payload,
/// plus the optional dark variant of the light/dark pair.
pub fn push(verb: &str, file: &Path, dark: Option<&Path>) -> Result<(), String> {
    if verb != "fresh" && verb != "update" {
        return Err(format!("verb must be fresh or update, got {verb}"));
    }
    let path = port_file().ok_or("cannot resolve home dir")?;
    let port_text = std::fs::read_to_string(&path)
        .map_err(|e| format!("read port-file {}: {e}", path.display()))?;
    let port: u16 = port_text
        .trim()
        .parse()
        .map_err(|e| format!("bad port in {}: {e}", path.display()))?;

    let bytes = std::fs::read(file).map_err(|e| format!("read {}: {e}", file.display()))?;
    let dark_bytes = match dark {
        Some(d) => Some(std::fs::read(d).map_err(|e| format!("read {}: {e}", d.display()))?),
        None => None,
    };
    let dark_len = dark_bytes.as_ref().map_or(0, Vec::len);

    let mut stream = TcpStream::connect(("127.0.0.1", port))
        .map_err(|e| format!("connect 127.0.0.1:{port}: {e}"))?;
    // CLI verb ("fresh"/"update") is the operator-facing ashlar; map it to the
    // sprued wire value (`pbgvw_fresh`/`pbgvw_update`). Keys carry `pbgvw_` too.
    // `pbgvw_dark_len` rides only when a dark variant is present, so a single
    // push stays byte-identical to the pre-pair frame.
    let control = if dark_len > 0 {
        format!(
            "{{\"pbgvw_verb\":\"pbgvw_{}\",\"pbgvw_id\":0,\"pbgvw_len\":{},\"pbgvw_dark_len\":{}}}\n",
            verb,
            bytes.len(),
            dark_len
        )
    } else {
        format!(
            "{{\"pbgvw_verb\":\"pbgvw_{}\",\"pbgvw_id\":0,\"pbgvw_len\":{}}}\n",
            verb,
            bytes.len()
        )
    };
    stream
        .write_all(control.as_bytes())
        .map_err(|e| e.to_string())?;
    stream.write_all(&bytes).map_err(|e| e.to_string())?;
    if let Some(d) = &dark_bytes {
        stream.write_all(d).map_err(|e| e.to_string())?;
    }
    stream.flush().map_err(|e| e.to_string())?;

    eprintln!(
        "pushed {} ({} bytes{}, verb {}) to 127.0.0.1:{port}",
        file.display(),
        bytes.len(),
        if dark_len > 0 {
            format!(" + dark {dark_len} bytes")
        } else {
            String::new()
        },
        verb
    );
    Ok(())
}

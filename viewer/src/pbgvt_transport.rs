// pbgvt — transport: the localhost-TCP wire, the port-file discovery channel,
// and the reference pusher client.
//
// Wire framing (the walking skeleton the protocol-freeze pace ratifies):
//   one JSON control line terminated by '\n', then exactly `len` payload bytes.
//   { "verb": "fresh" | "update", "id": <u64>, "len": <usize> }
// A connection may carry one frame or many, back to back.
//
// Discovery: the viewer binds an ephemeral port and writes it to a fixed
// port-file under ~/.config/paneboard/ (paneboard's per-user config home).
// Pushers read that file to find the listener. The walking skeleton is a single
// viewer instance, so one port-file suffices; per-`id` viewer instances are a
// later conductor concern that would key the file by id.

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
pub struct Frame {
    pub verb: Verb,
    pub id: u64,
    pub decoded: Decoded,
}

#[derive(Deserialize)]
struct Control {
    verb: String,
    #[serde(default)]
    id: u64,
    len: usize,
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
            "fresh" => Verb::Fresh,
            "update" => Verb::Update,
            other => {
                eprintln!("unknown verb: {other}");
                break;
            }
        };

        let mut payload = vec![0u8; ctrl.len];
        if let Err(e) = reader.read_exact(&mut payload) {
            eprintln!("payload read error ({} bytes): {e}", ctrl.len);
            break;
        }

        match pbgvd_decode::sniff_and_decode(payload) {
            Ok(decoded) => {
                if tx
                    .send(Frame {
                        verb,
                        id: ctrl.id,
                        decoded,
                    })
                    .is_err()
                {
                    break; // UI gone
                }
                ctx.request_repaint();
            }
            Err(e) => eprintln!("decode error: {e}"),
        }
    }
}

/// Reference pusher: read the port-file, connect, and send one framed payload.
pub fn push(verb: &str, file: &Path) -> Result<(), String> {
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

    let mut stream = TcpStream::connect(("127.0.0.1", port))
        .map_err(|e| format!("connect 127.0.0.1:{port}: {e}"))?;
    let control = format!("{{\"verb\":\"{}\",\"id\":0,\"len\":{}}}\n", verb, bytes.len());
    stream
        .write_all(control.as_bytes())
        .map_err(|e| e.to_string())?;
    stream.write_all(&bytes).map_err(|e| e.to_string())?;
    stream.flush().map_err(|e| e.to_string())?;

    eprintln!(
        "pushed {} ({} bytes, verb {}) to 127.0.0.1:{port}",
        file.display(),
        bytes.len(),
        verb
    );
    Ok(())
}

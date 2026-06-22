// paneboard-viewer — standalone SVG/raster diagram viewer.
//
// Two modes, dispatched on argv:
//   (default / `serve`)  run the viewer window + localhost-TCP listener.
//   `push <fresh|update> <file>`  reference pusher: connect to a running
//                                 viewer (via its port-file) and send one frame.
//
// The `push` mode is the walking skeleton's own test driver and the reference
// implementation of the wire framing that the protocol-freeze pace ratifies.

mod pbgvd_decode;
mod pbgvt_transport;
mod pbgvu_ui;

use std::process::ExitCode;

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().collect();

    if args.get(1).map(String::as_str) == Some("push") {
        let verb = args.get(2).map(String::as_str).unwrap_or("");
        let file = args.get(3).map(String::as_str).unwrap_or("");
        if verb.is_empty() || file.is_empty() {
            eprintln!("usage: paneboard-viewer push <fresh|update> <file>");
            return ExitCode::from(2);
        }
        return match pbgvt_transport::push(verb, std::path::Path::new(file)) {
            Ok(()) => ExitCode::SUCCESS,
            Err(e) => {
                eprintln!("push failed: {e}");
                ExitCode::FAILURE
            }
        };
    }

    match pbgvu_ui::run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("viewer failed: {e}");
            ExitCode::FAILURE
        }
    }
}

// pbgvd — decode: magic-byte format sniff, then decode to a uniform form.
//
// Format dispatch is by content sniff, not by any out-of-band type tag, so the
// payload is self-describing and PNG/JPEG ride the same wire path as SVG.
//
// The two arms are deliberately asymmetric to keep the heavy work off the UI
// thread: raster bytes are fully decoded to RGBA here (on the transport
// thread); SVG bytes are passed through untouched, because the usvg tree must
// live on the UI thread where zoom-driven re-rasterization happens.

/// A decoded frame payload, ready to hand to the UI thread. Both variants are
/// `Send` (no usvg tree here — SVG is parsed UI-side).
pub enum Decoded {
    /// Raw SVG source bytes; parsed into a usvg tree on the UI thread.
    Svg(Vec<u8>),
    /// Straight (unmultiplied) RGBA, row-major, `w * h * 4` bytes.
    Raster { rgba: Vec<u8>, w: u32, h: u32 },
}

/// Sniff `bytes` and decode. SVG passes through; everything else goes to the
/// `image` crate, which sniffs PNG/JPEG/etc. on its own.
pub fn sniff_and_decode(bytes: Vec<u8>) -> Result<Decoded, String> {
    if looks_like_svg(&bytes) {
        return Ok(Decoded::Svg(bytes));
    }
    let img = image::load_from_memory(&bytes).map_err(|e| e.to_string())?;
    let rgba = img.to_rgba8();
    let (w, h) = rgba.dimensions();
    Ok(Decoded::Raster {
        rgba: rgba.into_raw(),
        w,
        h,
    })
}

/// SVG detection. Raster payloads (PNG `0x89`, JPEG `0xFF`, …) open with binary
/// magic and never carry `<svg` in their header. SVG, by contrast, can be
/// preceded by a BOM, whitespace, an XML prolog, or a tool processing
/// instruction such as `<?plantuml 1.2026.2?>` — which PlantUML emits *ahead*
/// of the `<svg>` tag — so scan the head for the opening tag rather than
/// anchoring at byte 0.
fn looks_like_svg(bytes: &[u8]) -> bool {
    let head = &bytes[..bytes.len().min(1024)];
    head.windows(4).any(|w| w == b"<svg")
}

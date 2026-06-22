// pbgvu — UI: the egui window, the zoom/pan view state, and the fresh/update
// semantics. Owns rasterization, which is what makes `update`-at-held-zoom
// possible (a webview could not give this): an SVG source is re-rasterized from
// its usvg tree whenever the effective zoom moves, so it stays crisp; a raster
// source is GPU-scaled and is native-limited.

use std::sync::mpsc::Receiver;

use eframe::egui;

use crate::pbgvd_decode::Decoded;
use crate::pbgvt_transport::{self, Frame, Verb};

/// Cap a re-raster target so a deep zoom on a large SVG cannot demand an
/// absurd pixmap. The image still scales past this on the GPU (blurrier).
const MAX_RASTER_EDGE: u32 = 8192;
/// Re-raster an SVG only when the desired device scale departs this far from
/// the texture's current scale, so small zoom nudges don't thrash the decoder.
const RERASTER_RATIO: f32 = 1.25;

/// The live source, held UI-side so it can be re-rasterized on demand.
enum Source {
    Svg(resvg::usvg::Tree),
    Raster { rgba: Vec<u8>, w: u32, h: u32 },
}

struct ViewerApp {
    rx: Receiver<Frame>,
    port: u16,

    source: Option<Source>,
    /// Natural source size in source pixels.
    natural: egui::Vec2,
    /// Screen points per source pixel.
    zoom: f32,
    /// Top-left of the image within the panel, in panel-local points.
    pan: egui::Vec2,

    texture: Option<egui::TextureHandle>,
    /// Device px per source px the current SVG texture was rastered at
    /// (0.0 = no texture / not applicable).
    tex_scale: f32,

    /// Set by `fresh`: fit-to-window on the next frame, once the panel rect is known.
    fit_requested: bool,
    /// Last panel size seen; a change triggers a re-fit so the scale tracks the window.
    last_size: egui::Vec2,
    /// Zoom at the previous frame; used to detect a settled (non-moving) zoom so
    /// the crisp SVG re-raster is debounced until a gesture stops.
    last_zoom: f32,
}

pub fn run() -> Result<(), String> {
    let native_options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_title("paneboard viewer")
            .with_inner_size([900.0, 700.0]),
        ..Default::default()
    };
    eframe::run_native(
        "paneboard-viewer",
        native_options,
        Box::new(|cc| Ok(Box::new(ViewerApp::new(cc)))),
    )
    .map_err(|e| e.to_string())
}

impl ViewerApp {
    fn new(cc: &eframe::CreationContext<'_>) -> Self {
        let (tx, rx) = std::sync::mpsc::channel();
        let port = pbgvt_transport::serve(cc.egui_ctx.clone(), tx).unwrap_or_else(|e| {
            eprintln!("transport bind failed: {e}");
            0
        });
        Self {
            rx,
            port,
            source: None,
            natural: egui::vec2(1.0, 1.0),
            zoom: 1.0,
            pan: egui::Vec2::ZERO,
            texture: None,
            tex_scale: 0.0,
            fit_requested: false,
            last_size: egui::Vec2::ZERO,
            last_zoom: 1.0,
        }
    }

    fn apply_frame(&mut self, ctx: &egui::Context, frame: Frame) {
        let keep_view = matches!(frame.verb, Verb::Update);
        // The skeleton is single-window: `id` selects which viewer instance a
        // conductor would target, logged here but not yet routed.
        eprintln!(
            "frame: verb={} id={}",
            if keep_view { "update" } else { "fresh" },
            frame.id
        );
        let source = match frame.decoded {
            Decoded::Svg(bytes) => match parse_svg(&bytes) {
                Ok((tree, size)) => {
                    self.natural = size;
                    Source::Svg(tree)
                }
                Err(e) => {
                    eprintln!("svg parse failed: {e}");
                    return;
                }
            },
            Decoded::Raster { rgba, w, h } => {
                self.natural = egui::vec2(w as f32, h as f32);
                Source::Raster { rgba, w, h }
            }
        };
        self.source = Some(source);
        self.texture = None;
        self.tex_scale = 0.0;
        if !keep_view {
            self.fit_requested = true;
        }
        ctx.request_repaint();
    }

    /// Build or rebuild the display texture if needed. Raster sources texture
    /// once; SVG sources re-raster when the effective device scale has moved.
    fn ensure_texture(&mut self, ctx: &egui::Context) {
        let need = match &self.source {
            None => false,
            Some(Source::Raster { .. }) => self.texture.is_none(),
            Some(Source::Svg(_)) => {
                if self.texture.is_none() {
                    true
                } else {
                    // Debounce: re-raster only once the zoom has settled, so a
                    // smooth-scroll gesture GPU-scales the existing texture
                    // instead of re-rendering the whole SVG every frame.
                    let settled = (self.zoom - self.last_zoom).abs() < 1e-3;
                    let desired = (self.zoom * ctx.pixels_per_point()).max(0.001);
                    let ratio = (desired / self.tex_scale).max(self.tex_scale / desired);
                    settled && ratio > RERASTER_RATIO
                }
            }
        };
        if !need {
            return;
        }

        match &self.source {
            Some(Source::Raster { rgba, w, h }) => {
                let img =
                    egui::ColorImage::from_rgba_unmultiplied([*w as usize, *h as usize], rgba);
                self.texture =
                    Some(ctx.load_texture("frame", img, egui::TextureOptions::LINEAR));
            }
            Some(Source::Svg(tree)) => {
                let desired = (self.zoom * ctx.pixels_per_point()).clamp(0.02, 16.0);
                let mut pw = (self.natural.x * desired).round().max(1.0) as u32;
                let mut ph = (self.natural.y * desired).round().max(1.0) as u32;
                let longest = pw.max(ph);
                if longest > MAX_RASTER_EDGE {
                    let s = MAX_RASTER_EDGE as f32 / longest as f32;
                    pw = ((pw as f32) * s).round().max(1.0) as u32;
                    ph = ((ph as f32) * s).round().max(1.0) as u32;
                }
                if let Some(mut pixmap) = resvg::tiny_skia::Pixmap::new(pw, ph) {
                    let scale_x = pw as f32 / self.natural.x;
                    let scale_y = ph as f32 / self.natural.y;
                    let transform = resvg::tiny_skia::Transform::from_scale(scale_x, scale_y);
                    resvg::render(tree, transform, &mut pixmap.as_mut());
                    let img = egui::ColorImage::from_rgba_premultiplied(
                        [pw as usize, ph as usize],
                        pixmap.data(),
                    );
                    self.texture =
                        Some(ctx.load_texture("frame", img, egui::TextureOptions::LINEAR));
                    self.tex_scale = scale_x; // device px per source px actually used
                }
            }
            None => {}
        }
    }
}

impl eframe::App for ViewerApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        while let Ok(f) = self.rx.try_recv() {
            self.apply_frame(ctx, f);
        }

        egui::CentralPanel::default().show(ctx, |ui| {
            let (response, painter) =
                ui.allocate_painter(ui.available_size(), egui::Sense::click_and_drag());
            let rect = response.rect;

            if self.source.is_none() {
                painter.text(
                    rect.center(),
                    egui::Align2::CENTER_CENTER,
                    format!(
                        "paneboard viewer\nlistening on 127.0.0.1:{}\nwaiting for a pushed image…",
                        self.port
                    ),
                    egui::FontId::monospace(14.0),
                    egui::Color32::GRAY,
                );
                return;
            }

            // A panel resize re-fits, so the scale always tracks the window.
            if (rect.size() - self.last_size).length() > 0.5 {
                self.last_size = rect.size();
                self.fit_requested = true;
            }

            // The zoom-out floor: the scale at which the image just fits the panel.
            let fit_zoom = (rect.width() / self.natural.x)
                .min(rect.height() / self.natural.y)
                .max(0.001);

            // fresh / resize: fit-to-window, centered, once the panel rect is known.
            if self.fit_requested {
                let z = (rect.width() / self.natural.x).min(rect.height() / self.natural.y);
                self.zoom = if z.is_finite() && z > 0.0 { z } else { 1.0 };
                let displayed = self.natural * self.zoom;
                self.pan = (rect.size() - displayed) * 0.5;
                self.fit_requested = false;
            }

            // Zoom about the cursor (scroll wheel + trackpad pinch).
            let hover = response.hover_pos();
            let mut factor = 1.0_f32;
            ctx.input(|i| {
                let scroll = i.smooth_scroll_delta.y;
                if scroll.abs() > 0.0 {
                    factor *= (scroll * 0.0015).exp();
                }
                let zd = i.zoom_delta();
                if (zd - 1.0).abs() > 1e-4 {
                    factor *= zd;
                }
            });
            if (factor - 1.0).abs() > 1e-4 {
                if let Some(p) = hover {
                    let local = p - rect.min;
                    let new_zoom = (self.zoom * factor).clamp(fit_zoom, 64.0);
                    let real = new_zoom / self.zoom;
                    // Keep the source point under the cursor fixed.
                    self.pan = local - (local - self.pan) * real;
                    self.zoom = new_zoom;
                }
            }

            if response.dragged() {
                self.pan += response.drag_delta();
            }

            self.ensure_texture(ctx);

            // While the zoom is still moving, keep ticking so the debounced
            // crisp re-raster fires on the frame the gesture settles.
            if (self.zoom - self.last_zoom).abs() >= 1e-3 {
                ctx.request_repaint();
            }
            self.last_zoom = self.zoom;

            if let Some(tex) = &self.texture {
                let displayed = self.natural * self.zoom;
                let img_rect = egui::Rect::from_min_size(rect.min + self.pan, displayed);
                // White backing so transparent SVGs (dark ink, no background)
                // composite onto a defined surface, not the dark panel.
                painter.rect_filled(img_rect, 0.0, egui::Color32::WHITE);
                painter.image(
                    tex.id(),
                    img_rect,
                    egui::Rect::from_min_max(egui::pos2(0.0, 0.0), egui::pos2(1.0, 1.0)),
                    egui::Color32::WHITE,
                );
            }
        });
    }
}

/// Parse SVG bytes into a usvg tree, loading system fonts so diagram text
/// renders. Returns the tree and its natural size in source pixels.
fn parse_svg(bytes: &[u8]) -> Result<(resvg::usvg::Tree, egui::Vec2), String> {
    let mut opt = resvg::usvg::Options::default();
    opt.fontdb_mut().load_system_fonts();
    let tree = resvg::usvg::Tree::from_data(bytes, &opt).map_err(|e| e.to_string())?;
    let size = tree.size();
    Ok((tree, egui::vec2(size.width(), size.height())))
}

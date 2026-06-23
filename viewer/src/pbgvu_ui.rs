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

/// Backing behind the image in dark mode. The dark variant is light ink on a
/// transparent ground, so on the light backing it would be near-invisible;
/// this near-black ground (GitHub's dark canvas) is what the README `<picture>`
/// blocks composite onto in dark mode.
const DARK_BACKING: egui::Color32 = egui::Color32::from_rgb(0x0d, 0x11, 0x17);

/// Which variant of the light/dark pair the operator has selected. `d`/`l`
/// switch it; the *effective* variant falls back to light when no dark is held.
#[derive(Clone, Copy, PartialEq)]
enum Theme {
    Light,
    Dark,
}

/// The live source, held UI-side so it can be re-rasterized on demand.
enum Source {
    Svg(resvg::usvg::Tree),
    Raster { rgba: Vec<u8>, w: u32, h: u32 },
}

struct ViewerApp {
    rx: Receiver<Frame>,
    port: u16,

    /// The light variant — the always-present member of the pair.
    source: Option<Source>,
    /// The optional dark variant. `None` for a single-variant push, in which
    /// case the dark toggle falls back to `source`.
    dark: Option<Source>,
    /// The operator-selected variant; the effective one falls back to light
    /// when `dark` is `None`.
    theme: Theme,
    /// Natural source size in source pixels (the light variant's; the dark
    /// variant is the same diagram at the same size, so they share one viewport).
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
            dark: None,
            theme: Theme::Light,
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
            "frame: verb={} id={} dark={}",
            if keep_view { "update" } else { "fresh" },
            frame.id,
            frame.dark.is_some(),
        );
        let (light, natural) = match Self::decoded_to_source(frame.decoded) {
            Ok(v) => v,
            Err(e) => {
                eprintln!("svg parse failed (light): {e}");
                return;
            }
        };
        // The dark variant shares the light's natural size (same diagram); a
        // dark parse failure drops only the dark, never the whole frame.
        let dark = frame.dark.and_then(|d| match Self::decoded_to_source(d) {
            Ok((s, _)) => Some(s),
            Err(e) => {
                eprintln!("svg parse failed (dark, light kept): {e}");
                None
            }
        });

        self.natural = natural;
        self.source = Some(light);
        self.dark = dark;
        self.invalidate_texture();
        if !keep_view {
            // fresh resets to the default (light) variant and refits; update
            // retains the held variant and viewport.
            self.theme = Theme::Light;
            self.fit_requested = true;
        }
        ctx.request_repaint();
    }

    /// Convert a transport `Decoded` into a UI `Source`, parsing SVG into a
    /// usvg tree (raster is already RGBA). Returns the source and its natural
    /// size in source pixels.
    fn decoded_to_source(decoded: Decoded) -> Result<(Source, egui::Vec2), String> {
        match decoded {
            Decoded::Svg(bytes) => {
                let (tree, size) = parse_svg(&bytes)?;
                Ok((Source::Svg(tree), size))
            }
            Decoded::Raster { rgba, w, h } => {
                Ok((Source::Raster { rgba, w, h }, egui::vec2(w as f32, h as f32)))
            }
        }
    }

    /// Drop the current texture so `ensure_texture` rebuilds it — used on a new
    /// frame and on a variant switch (re-raster the other variant at the held
    /// zoom, never a refit).
    fn invalidate_texture(&mut self) {
        self.texture = None;
        self.tex_scale = 0.0;
    }

    /// The effective variant: dark only when selected *and* held; otherwise
    /// light. This is the single fallback point for a single-variant push.
    fn effective_dark(&self) -> bool {
        matches!(self.theme, Theme::Dark) && self.dark.is_some()
    }

    /// Build or rebuild the display texture if needed, from the active variant
    /// (`use_dark` picks dark vs light). Raster sources texture once; SVG
    /// sources re-raster when the effective device scale has moved.
    fn ensure_texture(&mut self, ctx: &egui::Context, use_dark: bool) {
        let active = if use_dark {
            self.dark.as_ref()
        } else {
            self.source.as_ref()
        };
        let need = match active {
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

        let active = if use_dark {
            self.dark.as_ref()
        } else {
            self.source.as_ref()
        };
        match active {
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

        // The viewer's first keystrokes: d/l switch the pair variant (retaining
        // zoom+pan — a switch only invalidates the texture, never refits), f
        // fits. Zoom/pan stay on scroll/drag, handled in-panel below.
        let (press_d, press_l, press_f) = ctx.input(|i| {
            (
                i.key_pressed(egui::Key::D),
                i.key_pressed(egui::Key::L),
                i.key_pressed(egui::Key::F),
            )
        });
        if press_d && self.theme != Theme::Dark {
            self.theme = Theme::Dark;
            self.invalidate_texture();
            ctx.request_repaint();
        }
        if press_l && self.theme != Theme::Light {
            self.theme = Theme::Light;
            self.invalidate_texture();
            ctx.request_repaint();
        }
        if press_f {
            self.fit_requested = true;
            ctx.request_repaint();
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

            let use_dark = self.effective_dark();
            self.ensure_texture(ctx, use_dark);

            // While the zoom is still moving, keep ticking so the debounced
            // crisp re-raster fires on the frame the gesture settles.
            if (self.zoom - self.last_zoom).abs() >= 1e-3 {
                ctx.request_repaint();
            }
            self.last_zoom = self.zoom;

            if let Some(tex) = &self.texture {
                let displayed = self.natural * self.zoom;
                let img_rect = egui::Rect::from_min_size(rect.min + self.pan, displayed);
                // Backing flips with the variant: white for light ink-on-nothing
                // SVGs, near-black for the dark variant (light ink), so each
                // composites onto the surface the README renders it against.
                let backing = if use_dark {
                    DARK_BACKING
                } else {
                    egui::Color32::WHITE
                };
                painter.rect_filled(img_rect, 0.0, backing);
                painter.image(
                    tex.id(),
                    img_rect,
                    egui::Rect::from_min_max(egui::pos2(0.0, 0.0), egui::pos2(1.0, 1.0)),
                    egui::Color32::WHITE,
                );
            }

            // Current-mode indicator: which variant is up (the effective one, so
            // a dark request on a single-variant push reads "light"). A faint
            // pill keeps it legible on either backing.
            let label = if use_dark { "dark" } else { "light" };
            let font = egui::FontId::monospace(12.0);
            let text_size = ctx.fonts(|f| {
                f.layout_no_wrap(label.to_owned(), font.clone(), egui::Color32::WHITE)
                    .size()
            });
            let pad = egui::vec2(6.0, 3.0);
            let origin = rect.left_top() + egui::vec2(8.0, 8.0);
            let pill = egui::Rect::from_min_size(origin, text_size + pad * 2.0);
            painter.rect_filled(pill, 4.0, egui::Color32::from_black_alpha(140));
            painter.text(
                origin + pad,
                egui::Align2::LEFT_TOP,
                label,
                font,
                egui::Color32::from_gray(220),
            );
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

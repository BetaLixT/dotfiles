//! Kanagawa "wave" water effect.
//!
//! The domain-warp field and the block-glyph shading are ported from Ly's
//! `src/animations/ColorMix.zig` (fairyglade/ly, WTFPL — so the port carries no
//! copyleft obligation into this GPL-3.0-only tree).
//!
//! This follows existing practice here: upstream's `doom.rs` opens "ported from
//! Ly's `src/animations/Doom.zig`". Note `matrix.rs` is *not* an Ly port — it is
//! cmatrix-style digital rain written independently.
//!
//! Ly's original is an isotropic plasma: it warps a UV coordinate three times
//! and indexes a 12-entry palette by `floor(length(uv) * 5.0) % 12`, where the
//! palette is four block glyphs crossed with three colour *pairs*.
//!
//! `wave` keeps that warp verbatim but uses it differently. Rather than letting
//! the warp pick both colour and glyph, a real water surface is computed from
//! superimposed sine components, cells below it are coloured by *depth* through
//! a Kanagawa blue ramp, and the warp only selects the shading glyph. The result
//! reads as moving water with a horizon instead of a swirl: the ramp gives
//! depth, the warp gives visible current.
//!
//! Steep crests are capped with foam, which is what keeps the surface from
//! looking like a plotted sine.

use tui::{
  buffer::Buffer,
  layout::{Position, Rect},
  style::Color,
};

use super::Animation;

/// Shading glyphs, lightest to densest (Ly's set).
const GLYPHS: [char; 4] = ['░', '▒', '▓', '█'];

/// Ly's `time_scale`: converts the frame counter into warp time.
const TIME_SCALE: f32 = 0.01;

/// Ly warps the UV coordinate three times per cell.
const WARP_ITERS: usize = 3;

/// Ly randomises these per run. Fixed here so the greeter looks the same on
/// every boot rather than re-rolling its character each time.
const COS_MOD: f32 = 1.7;
const SIN_MOD: f32 = 4.1;

/// Surface swell components: `(amplitude_rows, wavelength_cols,
/// speed_cols_per_frame, phase_radians)`.
///
/// The middle component runs against the other two, so the combined surface has
/// no short repeat period and never visibly tiles.
const COMPONENTS: [(f32, f32, f32, f32); 3] = [
  (3.2, 64.0, 0.23, 0.0),
  (1.8, 31.0, -0.15, 1.3),
  (0.9, 17.0, 0.32, 2.7),
];

/// Band indices into the depth ramp.
const BAND_CREST: u8 = 0;
const BAND_UPPER: u8 = 1;
const BAND_MID: u8 = 2;
const BAND_DEEP: u8 = 3;
const BAND_ABYSS: u8 = 4;
const BAND_FOAM: u8 = 5;

/// Sentinel for a cell above the waterline, which is left unpainted.
const BAND_SKY: u8 = u8::MAX;

/// Rows below the surface at which each band takes over.
const BAND_DEPTHS: [(u16, u8); 4] = [
  (0, BAND_CREST),
  (1, BAND_UPPER),
  (3, BAND_MID),
  (6, BAND_DEEP),
];

/// Configurable parameters for the wave effect.
#[derive(Debug, Clone)]
pub struct Options {
  /// Colour of the waterline itself.
  pub crest:      Color,
  /// Just below the surface.
  pub upper:      Color,
  /// Mid water.
  pub mid:        Color,
  /// Deep water.
  pub deep:       Color,
  /// The darkest depths, which fade into the container background.
  pub abyss:      Color,
  /// Foam on steep crests.
  pub foam:       Color,
  /// Resting waterline as a fraction of screen height, `0.0`–`1.0`.
  pub level:      f32,
  /// Multiplier on the swell amplitude. `1.0` is the tuned default.
  pub amplitude:  f32,
  /// Multiplier on the horizontal scroll speed.
  pub speed:      f32,
  /// How strongly the ported warp textures the water. `0.0` gives flat bands.
  pub warp:       f32,
  /// Surface gradient above which a crest gets foam. Higher = less foam.
  pub foam_slope: f32,
}

impl Default for Options {
  fn default() -> Self {
    Self {
      // Kanagawa: lightBlue, crystalBlue, waveAqua1, waveBlue2, waveBlue1,
      // fujiWhite.
      crest:      Color::Rgb(0xA3, 0xD4, 0xD5),
      upper:      Color::Rgb(0x7E, 0x9C, 0xD8),
      mid:        Color::Rgb(0x6A, 0x95, 0x89),
      deep:       Color::Rgb(0x2D, 0x4F, 0x67),
      abyss:      Color::Rgb(0x22, 0x32, 0x49),
      foam:       Color::Rgb(0xDC, 0xD7, 0xBA),
      level:      0.62,
      amplitude:  1.0,
      speed:      1.0,
      warp:       0.55,
      foam_slope: 0.55,
    }
  }
}

/// One painted cell: which depth band, and which shading glyph.
#[derive(Clone, Copy)]
struct WaterCell {
  band:  u8,
  glyph: u8,
}

impl Default for WaterCell {
  fn default() -> Self {
    Self {
      band:  BAND_SKY,
      glyph: 0,
    }
  }
}

pub struct Wave {
  width:  u16,
  height: u16,
  cells:  Vec<WaterCell>,
  frames: u64,
  opts:   Options,
}

impl Wave {
  #[must_use]
  pub fn new(mut opts: Options) -> Self {
    opts.level = opts.level.clamp(0.05, 0.95);
    opts.amplitude = opts.amplitude.max(0.0);
    opts.warp = opts.warp.max(0.0);
    opts.foam_slope = opts.foam_slope.max(0.0);

    Self {
      width:  0,
      height: 0,
      cells:  Vec::new(),
      frames: 0,
      opts,
    }
  }

  /// Ly's ColorMix domain warp, ported.
  ///
  /// Zig's `uv2 += uv + splat(length(uv))` adds the vector componentwise *and*
  /// the scalar length into both lanes; `uv -= splat(s)` subtracts a scalar
  /// from both. Both are spelled out here because the shorthand does not
  /// survive translation.
  fn warp(mut ux: f32, mut uy: f32, t: f32) -> f32 {
    let mut u2x = ux + uy;
    let mut u2y = ux + uy;

    for _ in 0..WARP_ITERS {
      let l = ux.hypot(uy);
      u2x += ux + l;
      u2y += uy + l;
      ux += 0.5 * (COS_MOD + u2y * 0.2 + t * 0.1).cos();
      uy += 0.5 * (SIN_MOD + u2x - t * 0.1).sin();
      let s = (ux + uy).cos() - (ux * 0.7 - uy).sin();
      ux -= s;
      uy -= s;
    }

    ux.hypot(uy)
  }

  /// Waterline row at column `x`, in fractional rows from the top.
  fn surface(&self, x: u16) -> f32 {
    let base = f32::from(self.height) * self.opts.level;
    let t = self.frames as f32;
    let xf = f32::from(x);

    let mut y = 0.0;
    for (amp, wavelength, speed, phase) in COMPONENTS {
      let k = std::f32::consts::TAU / wavelength;
      y += amp
        * self.opts.amplitude
        * (k * (xf - speed * self.opts.speed * t) + phase).sin();
    }

    base + y
  }

  /// Colour for a depth band.
  fn colour(&self, band: u8) -> Color {
    match band {
      BAND_CREST => self.opts.crest,
      BAND_UPPER => self.opts.upper,
      BAND_MID => self.opts.mid,
      BAND_DEEP => self.opts.deep,
      BAND_FOAM => self.opts.foam,
      _ => self.opts.abyss,
    }
  }
}

impl Animation for Wave {
  fn resize(&mut self, area: Rect) {
    if area.width == self.width
      && area.height == self.height
      && !self.cells.is_empty()
    {
      return;
    }
    self.width = area.width;
    self.height = area.height;
    self
      .cells
      .resize(self.width as usize * self.height as usize, WaterCell::default());
  }

  fn step(&mut self) {
    if self.width == 0 || self.height == 0 {
      return;
    }
    self.frames = self.frames.wrapping_add(1);

    let w = self.width as usize;
    let warp_t = self.frames as f32 * TIME_SCALE;

    // Surface height per column, plus the neighbours needed for the foam
    // gradient, computed once rather than per cell.
    let heights: Vec<f32> = (0..self.width).map(|x| self.surface(x)).collect();

    for x in 0..self.width {
      let xi = x as usize;
      let top = heights[xi];

      // Central difference on the surface; the ends reuse their only
      // neighbour rather than wrapping, which would inject a false crest.
      let left = heights[xi.saturating_sub(1)];
      let right = heights[(xi + 1).min(w - 1)];
      let slope = ((right - left) / 2.0).abs();
      let foam = slope > self.opts.foam_slope;

      // Round the fractional waterline up to the first fully-submerged row, so
      // that row is depth 0 and actually gets the crest colour. Truncating
      // instead would push every band down by one and the crest would never
      // be drawn for non-integer surface heights.
      let top_row = top.max(0.0).ceil() as u16;

      for y in 0..self.height {
        let idx = y as usize * w + xi;

        if y < top_row {
          self.cells[idx] = WaterCell::default();
          continue;
        }

        let depth = y - top_row;
        let mut band = BAND_ABYSS;
        for (limit, b) in BAND_DEPTHS {
          if depth <= limit {
            band = b;
            break;
          }
        }
        if band == BAND_CREST && foam {
          band = BAND_FOAM;
        }

        // The ported warp picks the shading glyph, giving the body of the
        // water a visible current instead of flat bands.
        let glyph = if self.opts.warp > 0.0 {
          let ux = (f32::from(x) * 2.0 - f32::from(self.width))
            / (f32::from(self.height) * 2.0);
          let uy =
            (f32::from(y) * 2.0 - f32::from(self.height)) / f32::from(self.height);
          let v = Self::warp(ux * self.opts.warp, uy * self.opts.warp, warp_t);
          ((v * 5.0) as usize) % GLYPHS.len()
        } else {
          GLYPHS.len() - 1
        };

        self.cells[idx] = WaterCell {
          band,
          glyph: glyph as u8,
        };
      }
    }
  }

  fn render(&self, area: Rect, buf: &mut Buffer) {
    if self.width == 0 || self.height == 0 {
      return;
    }
    let w = self.width as usize;

    for ly in 0..self.height {
      for lx in 0..self.width {
        let cell = self.cells[ly as usize * w + lx as usize];
        if cell.band == BAND_SKY {
          continue;
        }

        let x = area.x + lx;
        let y = area.y + ly;
        if let Some(out) = buf.cell_mut(Position { x, y }) {
          // Foam sits on the waterline, so it reads better as a half block
          // than as a shade.
          let ch = if cell.band == BAND_FOAM {
            '▀'
          } else {
            GLYPHS[cell.glyph as usize % GLYPHS.len()]
          };
          out.set_char(ch);
          out.set_fg(self.colour(cell.band));
          out.set_bg(Color::Reset);
        }
      }
    }
  }
}

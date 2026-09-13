#!/usr/bin/env python3
"""
Preview for the Kanagawa `wave` background animation for tuigreet.

Pure stdlib, installs nothing, touches nothing. Run it in alacritty, judge the
look, tune the constants below. The maths here is the reference implementation:
whatever looks right is what gets ported to Rust in wave.rs.

    python3 scripts/wave-preview.py                  # the wave
    python3 scripts/wave-preview.py --mode colormix  # faithful ly ColorMix port
    python3 scripts/wave-preview.py --no-box         # hide the login-box outline
    python3 scripts/wave-preview.py --fps 20

Ctrl+C to quit.

CREDIT / PROVENANCE
    The domain-warp field and the block-glyph dithering palette are ported from
    ly's ColorMix animation (src/animations/ColorMix.zig, GPL-3.0, fairyglade/ly).
    ly's original is an isotropic plasma: it indexes a 12-entry palette by
    `floor(length(uv) * 5.0) % 12`, where the palette is 4 block glyphs crossed
    with 3 colour PAIRS.

    `wave` keeps that warp verbatim and reuses it as the *water texture*, but
    replaces the radial index with a depth-based one and adds a real surface, so
    the result reads as moving water with a horizon rather than a swirl.
    `--mode colormix` runs the original mapping unchanged for comparison.
"""
import argparse, math, shutil, signal, sys, time

# --- Kanagawa palette -------------------------------------------------------
SUMI_INK1  = (0x1F, 0x1F, 0x28)   # background / sky
WAVE_BLUE1 = (0x22, 0x32, 0x49)   # deepest water
WAVE_BLUE2 = (0x2D, 0x4F, 0x67)   # deep
WAVE_AQUA1 = (0x6A, 0x95, 0x89)   # mid
CRYSTAL    = (0x7E, 0x9C, 0xD8)   # upper body
LIGHT_BLUE = (0xA3, 0xD4, 0xD5)   # crest
FUJI_WHITE = (0xDC, 0xD7, 0xBA)   # foam
ONI_VIOLET = (0x95, 0x7F, 0xB8)   # login-box outline (tuigreet's border colour)

GLYPHS = ("░", "▒", "▓", "█")   # ░ ▒ ▓ █  (ly's set)

# --- tunables ---------------------------------------------------------------
# Surface swell: (amplitude_rows, wavelength_cols, speed_cols_per_sec, phase).
# One component runs against the others so the pattern never visibly repeats.
COMPONENTS = [
    (3.2, 64.0,  7.0, 0.0),
    (1.8, 31.0, -4.5, 1.3),
    (0.9, 17.0,  9.5, 2.7),
]
WATER_LEVEL = 0.62     # resting surface, fraction of screen height
FOAM_SLOPE  = 0.55     # |d(surface)/dx| above which a crest gets foam
WARP_SCALE  = 0.55     # how strongly the ported warp textures the water
WARP_SPEED  = 1.0      # time multiplier for the warp
TIME_SCALE  = 0.01     # ly's ColorMix time_scale, frames -> time
DEPTH_BANDS = [        # (max rows below surface, colour)
    (0,  LIGHT_BLUE),
    (1,  CRYSTAL),
    (3,  WAVE_AQUA1),
    (6,  WAVE_BLUE2),
    (99, WAVE_BLUE1),
]
COLORMIX_COLS = (WAVE_BLUE1, CRYSTAL, WAVE_BLUE2)   # col1,col2,col3 for --mode colormix

COS_MOD = 1.7   # ly randomises these per run; fixed here so previews are comparable
SIN_MOD = 4.1


def fg(c): return f"\x1b[38;2;{c[0]};{c[1]};{c[2]}m"
def bg(c): return f"\x1b[48;2;{c[0]};{c[1]};{c[2]}m"


def warp(ux, uy, t, iters=3):
    """ly ColorMix's domain warp, ported verbatim.

    Zig's `uv2 += uv + splat(length(uv))` adds the vector componentwise AND the
    scalar length to both lanes; `uv -= splat(s)` subtracts a scalar from both.
    """
    u2x = u2y = ux + uy
    for _ in range(iters):
        l = math.hypot(ux, uy)
        u2x += ux + l
        u2y += uy + l
        ux += 0.5 * math.cos(COS_MOD + u2y * 0.2 + t * 0.1)
        uy += 0.5 * math.sin(SIN_MOD + u2x - t * 0.1)
        s = math.cos(ux + uy) - math.sin(ux * 0.7 - uy)
        ux -= s
        uy -= s
    return math.hypot(ux, uy)


def uv_of(x, y, w, h):
    """ly's normalisation: both axes divided by height, x doubled for cell aspect."""
    return ((x * 2 - w) / (h * 2.0), (y * 2 - h) / float(h))


def band(depth):
    for limit, colour in DEPTH_BANDS:
        if depth <= limit:
            return colour
    return DEPTH_BANDS[-1][1]


def box_geom(cols, rows):
    bw, bh = min(80, cols - 4), 9
    return (cols - bw) // 2, (rows - bh) // 2, bw, bh


def box_cell(x, y, g):
    bx, by, bw, bh = g
    if not (by <= y < by + bh and bx <= x < bx + bw):
        return None
    if y in (by, by + bh - 1) or x in (bx, bx + bw - 1):
        ch = "─" if y in (by, by + bh - 1) else "│"
        if   (y, x) == (by, bx):                   ch = "╭"
        elif (y, x) == (by, bx + bw - 1):          ch = "╮"
        elif (y, x) == (by + bh - 1, bx):          ch = "╰"
        elif (y, x) == (by + bh - 1, bx + bw - 1): ch = "╯"
        return (ONI_VIOLET, ch)
    return (None, " ")


def render_wave(cols, rows, t, frames, show_box):
    base = rows * WATER_LEVEL
    heights = []
    for x in range(cols):
        y = 0.0
        for amp, wl, sp, ph in COMPONENTS:
            y += amp * math.sin((2 * math.pi / wl) * (x - sp * t) + ph)
        heights.append(base + y)

    wt = frames * TIME_SCALE * WARP_SPEED
    g = box_geom(cols, rows)
    out, prev = [bg(SUMI_INK1)], None
    for y in range(rows):
        out.append(f"\x1b[{y+1};1H")
        for x in range(cols):
            colour, ch = None, " "
            top = int(heights[x])
            if y >= top:
                depth = y - top
                colour = band(depth)
                # ported warp picks the shading glyph -> visible current
                ux, uy = uv_of(x, y, cols, rows)
                v = warp(ux * WARP_SCALE, uy * WARP_SCALE, wt)
                ch = GLYPHS[int(v * 5.0) % len(GLYPHS)]
                if depth == 0:
                    slope = abs(heights[min(x+1, cols-1)] - heights[max(x-1, 0)]) / 2.0
                    if slope > FOAM_SLOPE:
                        colour, ch = FUJI_WHITE, "▀"
            if show_box:
                bc = box_cell(x, y, g)
                if bc is not None:
                    colour, ch = bc
            if colour != prev:
                out.append(fg(colour) if colour else "")
                prev = colour
            out.append(ch)
    return "".join(out)


def render_colormix(cols, rows, t, frames, show_box):
    """Faithful ly ColorMix: 12-entry palette indexed by the radial warp."""
    c1, c2, c3 = COLORMIX_COLS
    pairs = ((c1, c2), (c2, c3), (c3, c1))
    wt = frames * TIME_SCALE
    g = box_geom(cols, rows)
    out, prev_fg, prev_bg = [], None, None
    for y in range(rows):
        out.append(f"\x1b[{y+1};1H")
        for x in range(cols):
            ux, uy = uv_of(x, y, cols, rows)
            idx = int(math.floor(warp(ux, uy, wt) * 5.0)) % 12
            pf, pb = pairs[idx // 4]
            ch = GLYPHS[3 - (idx % 4)]      # ly orders █▓▒░
            f_, b_ = pf, pb
            if show_box:
                bc = box_cell(x, y, g)
                if bc is not None:
                    f_, ch = (bc[0] or pf), bc[1]
                    if bc[0] is None:
                        b_ = SUMI_INK1
            if b_ != prev_bg:
                out.append(bg(b_)); prev_bg = b_
            if f_ != prev_fg:
                out.append(fg(f_)); prev_fg = f_
            out.append(ch)
    return "".join(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fps", type=int, default=15,
                    help="preview only; Rust runs this far faster (default 15)")
    ap.add_argument("--mode", choices=("wave", "colormix"), default="wave")
    ap.add_argument("--no-box", action="store_true")
    a = ap.parse_args()

    cols, rows = shutil.get_terminal_size((120, 40))
    rows -= 1
    render = render_wave if a.mode == "wave" else render_colormix

    sys.stdout.write("\x1b[?25l\x1b[?1049h"); sys.stdout.flush()

    def restore(*_):
        sys.stdout.write("\x1b[?1049l\x1b[?25h\x1b[0m"); sys.stdout.flush()
        sys.exit(0)
    signal.signal(signal.SIGINT, restore)
    signal.signal(signal.SIGTERM, restore)

    t0, dt, frames = time.time(), 1.0 / a.fps, 0
    try:
        while True:
            frames += 1
            sys.stdout.write(render(cols, rows, time.time() - t0, frames, not a.no_box))
            sys.stdout.flush()
            time.sleep(dt)
    finally:
        restore()


if __name__ == "__main__":
    main()

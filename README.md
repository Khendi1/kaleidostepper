# Kaleidoscope Bench

A parametric, 3D-printable kaleidoscope **optical bench** — a modular rod/rail
system carrying an adjustable mirror head over a motorised subject stage, with a
camera at the vertex — plus a **ray-traced simulator** for working out what the
mirrors will actually do before you print them.

Two files, two halves of the same problem:

| File | What it is |
|---|---|
| [kaleidoscope_bench.scad](kaleidoscope_bench.scad) | The machine. Printable parts + assembly previews, all parametric. |
| [kaleidoscope_sim.py](kaleidoscope_sim.py) | The optics. Interactive 3-D ray tracer for mirror angle, length, width and shape. |

The bench is built to feed a video/glitch chain: camera at the vertex, subject
dish spinning underneath, WS2812 backlight, all driveable from a XIAO LFO/CV
source. The simulator exists because the interesting parameters (angle, length,
shape) are expensive to iterate in plastic and mirror stock.

---

## Part 1 — The bench (`kaleidoscope_bench.scad`)

Units are millimetres. Hardware is M3 unless noted. Open in OpenSCAD, pick a
part with the `part` variable, or use **Window ▸ Customizer** for sliders.

```openscad
part = "asm_full";   // whole instrument
part = "mirror_tray_a";  // one thing to print
```

### The idea

A "breadboard for optics": vertical smooth rods rise from a chassis board, a
**bridge** clamps both rails and cantilevers a platform over the dish centre,
and the mirror head hangs from that bridge. Everything slides and locks, so
mirror length, camera distance and stage height are all adjustable without
reprinting.

```
        camera  ─────────┐
        bridge  ═════╤═══╪═══╤═════   (clamps both rails, slides up/down)
                     │  head │         wedge yoke or tri brackets
      rails ║        │ mirror│        ║
            ║        │ tunnel│        ║
            ║        └───────┘        ║
                  ▓▓▓ dish ▓▓▓          subject stage
                  ═══ platter ═══       608 bearing, round-belt drive
            ╚════════ base ════════╝
             ┌── enclosure ──┐          NEMA-11 + driver + power
```

### Two interchangeable heads

These are **not** prototype-and-final. They make genuinely different images, and
which you want depends on the shot.

**2-mirror wedge** — `mirror_tray_a` + `mirror_tray_b` + `angle_gauge` + `wedge_yoke`

Two mirror strips hinged along the vertex by a 3 mm pin, opened to
`wedge_angle` by a drop-in gauge. Produces a single centred **mandala on a black
surround**. The black is intrinsic — the reflected circle simply doesn't reach a
rectangular frame's corners — and it keys out cleanly in a mixer. Its advantage
is that the angle is *adjustable*, so you can change the sector count live.

**3-mirror triangle** — `tri_bracket` ×2 + `tri_bracket_top` + 3 mirror strips

An equilateral tube. Produces **full-field tessellation**: the cell repeats edge
to edge with no black anywhere, an infinite wallpaper. Usually the better feed
for a video chain since there's no dead area to mask. The symmetry is fixed by
the triangle, so there's no live adjustment.

> Rule of thumb: **triangle** for full-frame texture, **wedge** for an
> adjustable centred mandala.

### Printable parts

| `part =` | What it is |
|---|---|
| `carriage` | Generic rod-clamp carriage — the rail building block |
| `mirror_tray_a` / `mirror_tray_b` | The two hinge phases of the wedge; knuckles interleave |
| `angle_gauge` | Drop-in wedge that sets the included angle. Regenerate per `wedge_angle` |
| `wedge_yoke` | Cradles the wedge's outer edges, bolts to the bridge. **Reprint if `wedge_angle` changes** |
| `tri_bracket` / `tri_bracket_top` | 3-mirror equilateral brackets; `_top` carries the bridge grid |
| `camera_mount` | Webcam / ¼"-20 carriage for the vertex |
| `rail_foot` | Bolts a rail end to the chassis board |
| `rail_bridge` | Clamps both rails, carries the head + camera over the dish |
| `turntable_base` | Stepper bracket + 608 bearing boss |
| `platter` | Geared turntable platter, V-groove rim, rides the bearing |
| `drive_pulley` | Grooved round-belt pulley for the stepper shaft |
| `subject_dish` | Shallow tray for oil/water/dye or beads |
| `led_ring` | WS2812 ring / backlight holder |
| `enclosure` | Electronics box under the base (power / rocker / pot / USB-C cutouts) |
| `all` | Everything scattered on the bed |

### Assembly previews

Not for printing — these place parts in their real relative positions.
`explode = 0…1` slides them apart; press **Animate** to spin the drive (`$t`).

`asm_full` · `asm_turntable` · `asm_wedge` · `asm_rail` · `asm_enclosure` ·
`wedge_asm` · `tri_head`

Set `head = "wedge"` or `"tri"` to choose which optic `asm_full` hangs.

### Key parameters

All at the top of the file.

| Parameter | Default | Notes |
|---|---|---|
| `rod_d` | 8 | Smooth-rod diameter. 6/10/12, or 25.4 for 1" rail |
| `fit` | 0.4 | Clearance added to bores and pockets — tune to your printer |
| `wedge_len` | 120 | Tunnel length along the optical axis = mirror strip length |
| `mirror_w` | 45 | Mirror width, out from the vertex |
| `wedge_angle` | 60 | Included angle. See the symmetry section below |
| `mirror_t` | 2 | Front-surface mirror strip thickness |
| `platter_od` / `pulley_od` | 140 / 20 | Belt reduction ≈ 7:1 |
| `dish_od` / `dish_depth` | 110 / 14 | Subject stage |
| `rail_foot_r` | 86 | Rail radius from centre — must clear the platter rim |
| `rail_span_ang` | 60 | Angular gap between the two rails |

### Bought hardware

- 2 × smooth rod, `rod_d` × `rail_len` (8 × 220 default)
- 3 mm rod or filament, 120 mm — wedge hinge pin
- Front-surface mirror strips, `mirror_w` × `wedge_len` × `mirror_t`
  (**2** for the wedge, **3** for the triangle)
- 608 bearing (22 OD / 8 ID / 7 thick)
- NEMA-11 stepper + driver
- Round rubber belt, 3–5 mm nitrile — size a touch short so it self-tensions
- WS2812 ring, ~66 OD / 50 ID (24 LED)
- M3 screws + nuts throughout; M2.5 for the stepper
- DC barrel jack (8 mm), KCD1-style rocker (21 × 15), 9 mm potentiometer
- Chassis board — plywood or acrylic, user-supplied

### Assembly notes

- **Chassis** — mount the enclosure and two `rail_foot`s to a shared board. Each
  foot bolts down with 2 × M3 and clamps a rod with its pinch bolt. Rails sit at
  `rail_foot_r` on the far side from the stepper so they clear the spinning
  platter.
- **Wedge** — glue a mirror strip into each tray channel, *reflective side to the
  interior*. Interleave the knuckles, slide the 3 mm pin down the vertex. Drop in
  an `angle_gauge` to set the angle; a rubber band holds the mirrors against it.
  Then slide the trays' outer edges into the `wedge_yoke` grips, nip the set
  screws, and bolt the yoke to the bridge — the gauge comes out once the yoke
  holds the angle (it's a setting jig, and being solid it plugs the tunnel).
- **Triangle** — glue one strip to each inner face of two brackets, using
  `tri_bracket_top` at the top for the bridge grid.
- **Turntable** — press a 608 into the base boss, press the platter hub into the
  bearing, bolt the NEMA-11 under the bracket, set-screw the pulley on its shaft.
  Loop the belt around pulley and platter grooves. It's a *friction* drive — keep
  oil off the belt and grooves.
- **Dish** — print the floor thin and translucent for backlighting; seal with
  silicone if you're running oil/water/dye.

---

## Part 2 — The simulator (`kaleidoscope_sim.py`)

Point it at an image and drag sliders to see what a given mirror set does to it.

### Install and run

```bash
pip install numpy pillow          # tkinter ships with Python
python kaleidoscope_sim.py                 # GUI, synthetic subject
python kaleidoscope_sim.py photo.jpg       # GUI on your image
```

### Why it ray-traces

The usual shortcut — fold the azimuth into `[0, θ]` — only ever reproduces the
*infinite mirror* limit. It cannot show the two things you most need to choose
on a real bench:

- **Mirror length** decides how many reflections fit before a ray runs off the
  end — i.e. how many rings of the mandala exist and where the field goes black.
- **Mirror shape** changes where rays escape along the tunnel, so a trapezoid
  bends the mandala's outer boundary away from a plain circle.

Both need finite mirrors in 3-D, so the sim traces rays: eye inside the tunnel
near `z = 0`, subject plane at `z = length`, reflecting off bounded mirror
polygons until a ray reaches the subject, escapes, or exhausts the bounce limit.

### Controls

**Mirror geometry** — mirror count (2 = open wedge, 3–6 = closed tube), wedge
angle, length, width, Rectangular/Trapezoidal toggle with a far/near taper
slider. A live schematic draws the cross-section and side view.

**Viewer** — eye position off the vertex line, eye Z, field of view.

**Optics** — max bounces, mirror reflectivity. Turning reflectivity down shows
why a long tunnel goes dim at the edges.

**Subject** — image span, rotation, pan, and what happens outside the image
(black / tile / mirror / clamp) or outside an open wedge.

It renders a fast preview while you drag and a crisp frame once the slider
settles. **Load image…** and **Save PNG…** do what they say.

### Contact sheets

Often the fastest way to build intuition — sweeps one parameter across a 3×3 grid:

```bash
python kaleidoscope_sim.py photo.jpg --grid wedge_angle
python kaleidoscope_sim.py photo.jpg --grid length
python kaleidoscope_sim.py photo.jpg --grid taper
# also: width, max_bounces, eye_offset
python kaleidoscope_sim.py photo.jpg --render out.png --size 1200
```

### Where the eye sits

The eye defaults to **2/3 of the way out along the wedge bisector** — the
centroid of the triangular aperture, which is exactly where the SCAD centres the
bridge grid (`acx = 2*mirror_w*cos(a)/3`, [kaleidoscope_bench.scad:310](kaleidoscope_bench.scad#L310)).

This matters more than it looks. Sitting *on* the vertex line, every direction
either goes straight down the open wedge or hits a mirror edge-on at zero
distance, so you'd see a single pie slice. Off the vertex line, directions
toward the mirror *faces* return reflected content, and that is what fills the
field into a circular mandala. The `Eye off axis` slider lets you sweep between
the two.

---

## Part 3 — Symmetry, and one correction worth knowing

The simulator's optics were verified by angular-Fourier analysis of rendered
frames rather than by eye. Two findings that bear directly on which
`angle_gauge` you print:

### Images ≠ rotational order

A wedge of included angle θ produces **N = 360/θ images**, but its rotational
symmetry is only **N/2 = 180/θ**. Reflection flips handedness, so adjacent
sectors are *mirrored*, not rotated, copies. A 60° wedge shows six sectors but
is group **D₃** — rotating it 60° does not map it onto itself; rotating 120°
does.

The `.scad` uses "sectors" correctly at
[line 231](kaleidoscope_bench.scad#L231); the looser "4/6/8/10/12-fold" in the
assembly notes means image count, not rotational order.

### 360/θ must be EVEN, not merely a whole number

The `.scad` states the wedge is seamless "as long as the angle divides 360
exactly." That's necessary but **not sufficient**. 72° divides 360 exactly, five
times — and it still shows a visible mismatch seam, because with an *odd* image
count the last sector meets the first with the wrong handedness. Confirmed both
visually and in the harmonic spectrum.

So the seamless angles are the ones giving an **even** image count:

| Angle | Images | Group | Seamless |
|---|---|---|---|
| 90° | 4 | D₂ | ✅ |
| 72° | 5 | — | ❌ odd — seam |
| 60° | 6 | D₃ | ✅ |
| 51.43° | 7 | — | ❌ odd — seam |
| 45° | 8 | D₄ | ✅ |
| 36° | 10 | D₅ | ✅ |
| 30° | 12 | D₆ | ✅ |
| 22.5° | 16 | D₈ | ✅ |
| 18° | 20 | D₁₀ | ✅ |

The SCAD's own recommended set (4/6/8/10/12) is already all-even, so the
practical advice was right — only the stated rule was incomplete. The
simulator's *snap to exact fold* checkbox snaps to even counts only, and the
readout flags an odd count as a seam.

### Tube modes

Only certain polygon tubes tile the plane. The sim reproduces this: the
triangle gives a clean **p6m** tessellation, the square **p4m**, while pentagon
and hexagon tubes drift and never close. This is the concrete reason the bench's
three-mirror head is equilateral.

### Tapered mirrors

Taper a *tube* and the tessellation wraps onto a sphere — the domed
"kaleidoscope ball" look. Taper a *wedge* and, because the trays stay hinged on
the axis, only the outer edge moves: the planes don't tilt, so what changes is
where rays escape, and the mandala's outer boundary stops being a plain circle.

Note that the current `mirror_tray` cuts **rectangular** channels, so trapezoidal
mirrors are exploratory in the sim only — you'd need modified trays (or just
hand-cut strips and rely on the lip) to build one.

---

## Using them together

The point of having both is to settle geometry before cutting mirror stock. The
parameters correspond directly:

| Simulator | SCAD | Default |
|---|---|---|
| `length` | `wedge_len` | 120 |
| `width` | `mirror_w` | 45 |
| `wedge_angle` | `wedge_angle` | 60 |
| mirror count 2 / 3 | `head = "wedge"` / `"tri"` | wedge |
| `eye_offset` 0.667 | `acx = 2*mirror_w*cos(a)/3` | centroid |
| `object_size` | `dish_od` | 110 |
| `reflectivity` | front-surface mirror quality | 0.95 |
| `taper` | *(no equivalent — trays are rectangular)* | 1.0 |

A reasonable workflow:

1. Run `--grid wedge_angle` on a photo of your actual subject medium to pick a
   sector count you like.
2. Set the sim's `object_size` to **110** to match `dish_od`, then sweep
   `--grid length` to find the shortest tunnel that still fills the field — short
   mirrors are cheaper, stiffer and easier to light.
3. Check `max_bounces` and `reflectivity` together. If the pattern only looks
   right above ~20 bounces, real mirrors will lose it to attenuation at the
   edges; shorten the tunnel or widen the angle.
4. Print `angle_gauge` and `wedge_yoke` at the chosen `wedge_angle` — both are
   cut at ±`wedge_angle`/2 and must be regenerated together.

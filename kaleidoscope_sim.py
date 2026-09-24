"""
kaleidoscope_sim.py - interactive 3-D ray-traced kaleidoscope simulator.

Companion to kaleidoscope_bench.scad.  Point it at an image (the "subject
dish") and drag sliders to see what the mirror tunnel actually does to it.

Why a real ray tracer and not a 2-D polar fold?
    The usual trick (fold the azimuth into [0, theta]) only ever reproduces the
    infinite-mirror limit.  It cannot show you the two things you most want to
    tune on a physical bench:
      * mirror LENGTH - how many reflections fit before a ray runs off the end,
        i.e. how many rings of the mandala exist and where the field goes black;
      * mirror SHAPE - a trapezoid clips the escape boundary differently along
        the tunnel, so the mandala's outer edge stops being a plain circle.
    Both need finite mirrors in 3-D, so we trace rays.

Geometry (mm, matching the .scad):
    +z is the optical axis.  Mirrors run z = 0 (eye end) .. z = length.
    The subject sits on the plane z = length.  The eye is inside the tunnel
    near z = 0 and looks toward the axis point (0, 0, length).

    2 mirrors  -> open wedge; vertex line on the z axis, included angle
                  `wedge_angle`.  Trapezoid = the outer edge tapers, so the
                  planes stay put and only the escape aperture changes.  This
                  is the buildable shape for the hinged tray design, where the
                  hinge pin pins the vertex to the axis.
    3+ mirrors -> closed regular-polygon tube, side length = `width`.
                  Trapezoid = the tube itself cones in or out (mirrors tilt),
                  which is the classic tapered kaleidoscope.

Run:
    python kaleidoscope_sim.py                  # GUI, synthetic subject
    python kaleidoscope_sim.py photo.jpg        # GUI on your image
    python kaleidoscope_sim.py photo.jpg --render out.png --size 1200
    python kaleidoscope_sim.py photo.jpg --grid wedge_angle --out sweep.png
"""

from __future__ import annotations

import argparse
import math
import os
import queue
import sys
import threading
from dataclasses import dataclass, replace

import numpy as np

F32 = np.float32
EPS = 1e-5


# ---------------------------------------------------------------------------
# configuration
# ---------------------------------------------------------------------------

@dataclass
class Config:
    # --- mirror geometry -------------------------------------------------
    n_mirrors: int = 2         # 2 = open wedge, >=3 = closed polygon tube
    wedge_angle: float = 60.0  # included angle in degrees (2-mirror only)
    length: float = 120.0      # tunnel length along the optical axis
    width: float = 45.0        # mirror strip width at the eye end
    taper: float = 1.0         # far width / near width; 1.0 == rectangular

    # --- viewer ----------------------------------------------------------
    eye_offset: float = 0.667  # fraction of the aperture half-width, from axis
    eye_z: float = 0.0         # <0 puts the eye behind the mirror entrance
    fov: float = 60.0          # vertical field of view, degrees
    aim_axis: bool = True      # aim at (0,0,length) instead of straight ahead

    # --- optics ----------------------------------------------------------
    max_bounces: int = 24
    reflectivity: float = 0.95

    # --- subject ---------------------------------------------------------
    object_size: float = 180.0  # mm spanned by the image width at z = length
    object_rot: float = 0.0
    object_dx: float = 0.0
    object_dy: float = 0.0
    edge_mode: str = "black"    # black | tile | mirror | clamp
    outside_mode: str = "black"  # black | object - rays that leave an open wedge

    # --- render ----------------------------------------------------------
    supersample: int = 1

    # -- symmetry bookkeeping (2-mirror case) -----------------------------
    #
    # Two mirrors at included angle t generate a dihedral group.  Careful:
    # the number of IMAGES is N = 360/t, but the ROTATIONAL order is only
    # N/2 = 180/t, because reflection flips handedness and adjacent sectors
    # are mirrored, not rotated, copies.  A 60 deg wedge therefore shows six
    # sectors but is group D3 - rotating it by 60 deg does NOT map it onto
    # itself, rotating by 120 deg does.
    #
    # The tiling only closes seamlessly when N is an EVEN integer; odd N
    # leaves the last sector meeting the first with the wrong handedness.

    def images(self) -> float:
        """Number of visible sectors / copies of the subject wedge."""
        return 360.0 / max(self.wedge_angle, 1e-6)

    def rot_order(self) -> float:
        """Order of the rotational subgroup (mirror lines = same number)."""
        return 180.0 / max(self.wedge_angle, 1e-6)

    def is_exact(self, tol: float = 0.02) -> bool:
        """True when the wedge tiles the circle with no mismatch seam."""
        n = self.images()
        return abs(n - round(n)) < tol and round(n) >= 2 and round(n) % 2 == 0


# ---------------------------------------------------------------------------
# mirror geometry
# ---------------------------------------------------------------------------

@dataclass
class Mirror:
    """A planar mirror strip.

    The reflective side satisfies  p . n >= c  (n is the INWARD normal).
    The strip is bounded by  0 <= p.z <= length  and
    lo0 + lo1*p.z <= p . lat <= hi0 + hi1*p.z.
    """
    n: np.ndarray
    c: float
    lat: np.ndarray
    lo0: float
    lo1: float
    hi0: float
    hi1: float


def build_geometry(cfg: Config):
    """Return (mirrors, extra_halfspaces, length).

    extra_halfspaces are (n, c0, c1) meaning p.n >= c0 + c1*p.z.  They close
    off the open side of a wedge so we can tell "escaped out the side" from
    "reached the subject".
    """
    L = max(float(cfg.length), 1e-3)
    mirrors: list[Mirror] = []
    extra: list[tuple[np.ndarray, float, float]] = []

    if cfg.n_mirrors <= 2:
        half = math.radians(cfg.wedge_angle) * 0.5
        ch, sh = math.cos(half), math.sin(half)
        w_near = float(cfg.width)
        w_far = float(cfg.width) * float(cfg.taper)
        slope = (w_far - w_near) / L

        # Both mirrors contain the z axis (the hinge pin), so c == 0.
        # lat is the in-plane direction pointing away from the vertex, so
        # p . lat is exactly the distance out from the hinge.
        u_a = np.array([ch, sh, 0.0], F32)
        n_a = np.array([sh, -ch, 0.0], F32)
        u_b = np.array([ch, -sh, 0.0], F32)
        n_b = np.array([sh, ch, 0.0], F32)
        mirrors.append(Mirror(n_a, 0.0, u_a, 0.0, 0.0, w_near, slope))
        mirrors.append(Mirror(n_b, 0.0, u_b, 0.0, 0.0, w_near, slope))

        # Open side: the chord joining the two outer edges, at x = w(z)*cos(half).
        extra.append((np.array([-1.0, 0.0, 0.0], F32), -w_near * ch, -slope * ch))
    else:
        n_sides = int(cfg.n_mirrors)
        tan_n = math.tan(math.pi / n_sides)
        # inradius from side length; for n=3 this is width/(2*sqrt(3)),
        # matching tri_ri() in the .scad.
        r_near = float(cfg.width) / (2.0 * tan_n)
        r_far = float(cfg.width) * float(cfg.taper) / (2.0 * tan_n)
        k = (r_far - r_near) / L          # d(inradius)/dz - the cone taper
        scale = math.hypot(1.0, k)

        for i in range(n_sides):
            phi = 2.0 * math.pi * i / n_sides + math.pi / 2.0
            cx, cy = math.cos(phi), math.sin(phi)
            # plane: p.(cx,cy,0) - k*p.z = r_near  ->  wall sits at r_near + k*z
            m = np.array([cx, cy, -k], F32) / scale
            mirrors.append(Mirror(
                n=(-m).astype(F32),
                c=-r_near / scale,
                lat=np.array([-math.sin(phi), math.cos(phi), 0.0], F32),
                lo0=-r_near * tan_n, lo1=-k * tan_n,
                hi0=r_near * tan_n, hi1=k * tan_n,
            ))

    return mirrors, extra, L


def aperture_half_width(cfg: Config, z: float, L: float) -> float:
    """Distance from the axis to the wall along +x, at height z."""
    zc = min(max(z, 0.0), L)
    if cfg.n_mirrors <= 2:
        half = math.radians(cfg.wedge_angle) * 0.5
        w = cfg.width + (cfg.width * cfg.taper - cfg.width) * zc / L
        return w * math.cos(half)
    tan_n = math.tan(math.pi / cfg.n_mirrors)
    r_near = cfg.width / (2.0 * tan_n)
    r_far = cfg.width * cfg.taper / (2.0 * tan_n)
    return r_near + (r_far - r_near) * zc / L


def eye_position(cfg: Config, L: float) -> np.ndarray:
    """Where the pupil sits.

    Default for a wedge is 2/3 of the way out along the bisector, i.e. the
    centroid of the triangular aperture - the same point kaleidoscope_bench.scad
    centres the camera bridge on (acx = 2*mirror_w*cos(a)/3).  Sitting ON the
    vertex line would only ever show a single pie slice; being off it is what
    lets you look INTO the mirror faces, which is what fills the field.
    """
    x = cfg.eye_offset * aperture_half_width(cfg, cfg.eye_z, L)
    return np.array([x, 0.0, cfg.eye_z], F32)


def inside_tunnel(p: np.ndarray, mirrors, extra) -> np.ndarray:
    ok = np.ones(p.shape[0], bool)
    for m in mirrors:
        ok &= (p @ m.n) >= (m.c - 1e-4)
    for n, c0, c1 in extra:
        ok &= (p @ n) >= (c0 + c1 * p[:, 2] - 1e-4)
    return ok


# ---------------------------------------------------------------------------
# subject sampling
# ---------------------------------------------------------------------------

def sample_object(img: np.ndarray, x: np.ndarray, y: np.ndarray, cfg: Config):
    """Bilinear lookup of the subject plane at world (x, y).  Returns (rgb, valid)."""
    ih, iw = img.shape[:2]
    r = math.radians(cfg.object_rot)
    cr, sr = math.cos(r), math.sin(r)
    xr = cr * x + sr * y - cfg.object_dx
    yr = -sr * x + cr * y - cfg.object_dy

    span_w = max(float(cfg.object_size), 1e-3)
    span_h = span_w * ih / iw
    u = xr / span_w + 0.5
    v = 0.5 - yr / span_h

    valid = np.ones(u.shape, F32)
    mode = cfg.edge_mode
    if mode == "black":
        valid = ((u >= 0.0) & (u <= 1.0) & (v >= 0.0) & (v <= 1.0)).astype(F32)
        u = np.clip(u, 0.0, 1.0)
        v = np.clip(v, 0.0, 1.0)
    elif mode == "tile":
        u = np.mod(u, 1.0)
        v = np.mod(v, 1.0)
    elif mode == "mirror":
        tu = np.mod(u, 2.0)
        u = np.where(tu > 1.0, 2.0 - tu, tu)
        tv = np.mod(v, 2.0)
        v = np.where(tv > 1.0, 2.0 - tv, tv)
    else:  # clamp
        u = np.clip(u, 0.0, 1.0)
        v = np.clip(v, 0.0, 1.0)

    fx = u * (iw - 1)
    fy = v * (ih - 1)
    x0 = np.clip(np.floor(fx).astype(np.int32), 0, max(iw - 2, 0))
    y0 = np.clip(np.floor(fy).astype(np.int32), 0, max(ih - 2, 0))
    x1 = np.minimum(x0 + 1, iw - 1)
    y1 = np.minimum(y0 + 1, ih - 1)
    tx = (fx - x0).astype(F32)[:, None]
    ty = (fy - y0).astype(F32)[:, None]

    top = img[y0, x0] * (1.0 - tx) + img[y0, x1] * tx
    bot = img[y1, x0] * (1.0 - tx) + img[y1, x1] * tx
    return top * (1.0 - ty) + bot * ty, valid


# ---------------------------------------------------------------------------
# renderer
# ---------------------------------------------------------------------------

def render(cfg: Config, img: np.ndarray, width: int, height: int,
           cancel: threading.Event | None = None) -> np.ndarray:
    """Trace the tunnel.  Returns an (height, width, 3) uint8 image."""
    mirrors, extra, L = build_geometry(cfg)
    eye = eye_position(cfg, L)

    if cfg.aim_axis:
        fwd = np.array([0.0, 0.0, L], F32) - eye
    else:
        fwd = np.array([0.0, 0.0, 1.0], F32)
    fwd = fwd / np.linalg.norm(fwd)
    right = np.cross(fwd, np.array([0.0, 1.0, 0.0], F32))
    nr = np.linalg.norm(right)
    right = np.array([1.0, 0.0, 0.0], F32) if nr < 1e-6 else (right / nr).astype(F32)
    up = np.cross(right, fwd).astype(F32)

    ss = max(1, int(cfg.supersample))
    rw, rh = width * ss, height * ss
    tan_half = math.tan(math.radians(min(max(cfg.fov, 1.0), 170.0)) * 0.5)

    px = (np.arange(rw, dtype=F32) + 0.5) / rw * 2.0 - 1.0
    py = 1.0 - (np.arange(rh, dtype=F32) + 0.5) / rh * 2.0
    sx = (px * tan_half * (rw / rh)).astype(F32)
    sy = (py * tan_half).astype(F32)

    d = (fwd[None, None, :]
         + sx[None, :, None] * right[None, None, :]
         + sy[:, None, None] * up[None, None, :]).reshape(-1, 3).astype(F32)
    d /= np.linalg.norm(d, axis=1, keepdims=True)

    n_rays = d.shape[0]
    out = np.zeros((n_rays, 3), F32)
    o = np.repeat(eye[None, :], n_rays, axis=0)
    atten = np.ones(n_rays, F32)
    idx = np.arange(n_rays, dtype=np.int64)

    normals = np.stack([m.n for m in mirrors]).astype(F32)
    refl = F32(min(max(cfg.reflectivity, 0.0), 1.0))
    open_wedge_black = (cfg.n_mirrors <= 2 and cfg.outside_mode == "black")

    for _ in range(int(cfg.max_bounces) + 1):
        if idx.size == 0:
            break
        if cancel is not None and cancel.is_set():
            break

        # distance to the subject plane
        dz = d[:, 2]
        fwd_ok = dz > 1e-9
        t_obj = np.where(fwd_ok, (L - o[:, 2]) / np.where(fwd_ok, dz, F32(1.0)),
                         np.inf).astype(F32)
        t_obj = np.where(t_obj > EPS, t_obj, np.inf)

        best = t_obj.copy()
        which = np.full(idx.size, -1, np.int32)

        for mi, m in enumerate(mirrors):
            denom = d @ m.n
            live = np.abs(denom) > 1e-9
            if not live.any():
                continue
            t = (m.c - (o @ m.n)) / np.where(live, denom, F32(1.0))
            cand = live & (t > EPS) & (t < best)
            if not cand.any():
                continue
            p = o + t[:, None] * d
            pz = p[:, 2]
            lat = p @ m.lat
            cand &= (pz >= -1e-3) & (pz <= L + 1e-3)
            cand &= (lat >= m.lo0 + m.lo1 * pz - 1e-3)
            cand &= (lat <= m.hi0 + m.hi1 * pz + 1e-3)
            if not cand.any():
                continue
            best = np.where(cand, t, best).astype(F32)
            which = np.where(cand, mi, which)

        hit_obj = (which < 0) & np.isfinite(best)
        hit_mir = which >= 0

        # --- rays that made it to the subject -----------------------------
        if hit_obj.any():
            sel = np.nonzero(hit_obj)[0]
            p = o[sel] + best[sel, None] * d[sel]
            rgb, valid = sample_object(img, p[:, 0], p[:, 1], cfg)
            gain = atten[sel] * valid
            if open_wedge_black:
                gain = gain * inside_tunnel(p, mirrors, extra).astype(F32)
            out[idx[sel]] = rgb * gain[:, None]

        # --- rays that hit a mirror ---------------------------------------
        alive = hit_mir.copy()
        if hit_mir.any():
            sel = np.nonzero(hit_mir)[0]
            nrm = normals[which[sel]]
            dd = d[sel]
            dn = np.einsum("ij,ij->i", dd, nrm).astype(F32)
            # dn > 0 means we arrived at the unsilvered back of the strip.
            back = dn > 0.0
            p = o[sel] + best[sel, None] * dd
            new_d = dd - 2.0 * dn[:, None] * nrm
            o[sel] = p + new_d * F32(1e-3)
            d[sel] = new_d
            alive[sel[back]] = False

        o = o[alive]
        d = d[alive]
        atten = atten[alive] * refl
        idx = idx[alive]

    # rays still alive here exhausted max_bounces -> left black on purpose,
    # so raising the slider visibly grows the mandala outward.
    frame = out.reshape(rh, rw, 3)
    if ss > 1:
        frame = frame.reshape(height, ss, width, ss, 3).mean(axis=(1, 3))
    return np.clip(frame * 255.0 + 0.5, 0, 255).astype(np.uint8)


# ---------------------------------------------------------------------------
# subject images
# ---------------------------------------------------------------------------

def synthetic_subject(size: int = 512, seed: int = 7) -> np.ndarray:
    """Smooth colour blobs plus a few hard edges, so both hue symmetry and
    edge symmetry are readable without needing a photo."""
    rng = np.random.default_rng(seed)
    coarse = rng.random((7, 7, 3)).astype(F32)
    yy = np.linspace(0, 6, size, dtype=F32)
    xx = np.linspace(0, 6, size, dtype=F32)
    y0 = np.clip(np.floor(yy).astype(int), 0, 5)
    x0 = np.clip(np.floor(xx).astype(int), 0, 5)
    ty = (yy - y0)[:, None, None]
    tx = (xx - x0)[None, :, None]
    ty = ty * ty * (3 - 2 * ty)
    tx = tx * tx * (3 - 2 * tx)
    top = coarse[y0][:, x0] * (1 - tx) + coarse[y0][:, x0 + 1] * tx
    bot = coarse[y0 + 1][:, x0] * (1 - tx) + coarse[y0 + 1][:, x0 + 1] * tx
    img = top * (1 - ty) + bot * ty

    gy, gx = np.mgrid[0:size, 0:size].astype(F32)
    for _ in range(9):
        cx, cy = rng.uniform(0.1, 0.9, 2) * size
        r = rng.uniform(0.03, 0.11) * size
        col = rng.random(3).astype(F32)
        mask = ((gx - cx) ** 2 + (gy - cy) ** 2) < r * r
        img[mask] = col
    return np.clip(img, 0, 1).astype(F32)


def load_subject(path: str) -> np.ndarray:
    from PIL import Image
    im = Image.open(path).convert("RGB")
    im.thumbnail((1400, 1400), Image.LANCZOS)
    return (np.asarray(im, dtype=F32) / 255.0)


# ---------------------------------------------------------------------------
# GUI
# ---------------------------------------------------------------------------

def run_gui(cfg: Config, img: np.ndarray, subject_name: str) -> None:
    import tkinter as tk
    from tkinter import ttk, filedialog, messagebox
    from PIL import Image, ImageTk

    PREVIEW = 300
    FULL = 760

    state = {"cfg": cfg, "img": img, "subject": subject_name,
             "photo": None, "frame": None, "job": None}

    jobs: "queue.Queue" = queue.Queue()
    results: "queue.Queue" = queue.Queue()
    cancel = threading.Event()

    def worker():
        while True:
            item = jobs.get()
            if item is None:
                return
            # drain to the newest request
            while True:
                try:
                    item = jobs.get_nowait()
                    if item is None:
                        return
                except queue.Empty:
                    break
            c, im, size, final = item
            cancel.clear()
            try:
                frame = render(c, im, size, size, cancel)
            except Exception as exc:  # keep the UI alive on bad params
                results.put(("error", str(exc)))
                continue
            if not cancel.is_set():
                results.put(("ok", frame, final))

    threading.Thread(target=worker, daemon=True).start()

    root = tk.Tk()
    root.title("Kaleidoscope simulator")
    root.geometry("1220x860")

    main = ttk.Frame(root, padding=8)
    main.pack(fill="both", expand=True)

    left = ttk.Frame(main)
    left.pack(side="left", fill="y", padx=(0, 10))
    rightp = ttk.Frame(main)
    rightp.pack(side="left", fill="both", expand=True)

    view = tk.Canvas(rightp, bg="#101014", highlightthickness=0,
                     width=FULL, height=FULL)
    view.pack(fill="both", expand=True)
    status = ttk.Label(rightp, text="", anchor="w")
    status.pack(fill="x", pady=(6, 0))

    # -- control plumbing --------------------------------------------------
    vars_: dict[str, tk.Variable] = {}
    updating = {"lock": False}

    def request(final: bool) -> None:
        size = FULL if final else PREVIEW
        cancel.set()
        jobs.put((replace(state["cfg"]), state["img"], size, final))

    def schedule() -> None:
        """Cheap preview now, full-res once the slider settles."""
        if updating["lock"]:
            return
        request(False)
        if state["job"] is not None:
            root.after_cancel(state["job"])
        state["job"] = root.after(260, lambda: request(True))

    def set_field(name: str, value) -> None:
        state["cfg"] = replace(state["cfg"], **{name: value})
        refresh_labels()
        draw_schematic()
        schedule()

    def add_slider(parent, name, label, lo, hi, fmt="{:.1f}", step=None,
                   cast=float):
        row = ttk.Frame(parent)
        row.pack(fill="x", pady=1)
        ttk.Label(row, text=label, width=15).pack(side="left")
        val = ttk.Label(row, text="", width=7, anchor="e")
        val.pack(side="right")
        var = tk.DoubleVar(value=float(getattr(state["cfg"], name)))
        vars_[name] = var

        def on_move(_evt=None):
            v = var.get()
            if step:
                v = round(v / step) * step
            v = cast(v)
            val.config(text=fmt.format(v))
            if cast(getattr(state["cfg"], name)) != v:
                set_field(name, v)
            else:
                val.config(text=fmt.format(v))

        sc = ttk.Scale(row, from_=lo, to=hi, variable=var,
                       command=lambda _v: on_move())
        sc.pack(side="left", fill="x", expand=True, padx=4)
        val.config(text=fmt.format(cast(getattr(state["cfg"], name))))
        return sc, val

    # -- mirror geometry ---------------------------------------------------
    g = ttk.LabelFrame(left, text="Mirror geometry", padding=6)
    g.pack(fill="x", pady=(0, 6))

    row = ttk.Frame(g)
    row.pack(fill="x", pady=2)
    ttk.Label(row, text="Mirrors", width=15).pack(side="left")
    mirror_var = tk.StringVar(value="2  (open wedge)")
    mirror_box = ttk.Combobox(row, textvariable=mirror_var, state="readonly",
                              width=18, values=["2  (open wedge)",
                                                "3  (triangle tube)",
                                                "4  (square tube)",
                                                "5  (pentagon tube)",
                                                "6  (hexagon tube)"])
    mirror_box.pack(side="left", fill="x", expand=True, padx=4)

    angle_sc, angle_lbl = add_slider(g, "wedge_angle", "Wedge angle", 8, 150,
                                     "{:.1f}°")
    snap_var = tk.BooleanVar(value=True)
    fold_lbl = ttk.Label(g, text="", foreground="#2a6f2a")
    ttk.Checkbutton(g, text="snap to exact fold (360/n)", variable=snap_var,
                    command=lambda: apply_snap()).pack(anchor="w")
    fold_lbl.pack(anchor="w", pady=(0, 4))

    add_slider(g, "length", "Mirror length", 10, 400, "{:.0f}")
    add_slider(g, "width", "Mirror width", 5, 160, "{:.0f}")

    shape_var = tk.StringVar(value="rect")
    srow = ttk.Frame(g)
    srow.pack(fill="x", pady=(4, 0))
    ttk.Label(srow, text="Shape", width=15).pack(side="left")
    ttk.Radiobutton(srow, text="Rectangular", value="rect", variable=shape_var,
                    command=lambda: on_shape()).pack(side="left")
    ttk.Radiobutton(srow, text="Trapezoidal", value="trap", variable=shape_var,
                    command=lambda: on_shape()).pack(side="left")
    taper_sc, taper_lbl = add_slider(g, "taper", "  far/near width", 0.15, 3.0,
                                     "{:.2f}")
    shape_note = ttk.Label(g, text="", foreground="#666", wraplength=270,
                           justify="left")
    shape_note.pack(anchor="w", pady=(2, 0))

    # -- viewer ------------------------------------------------------------
    v = ttk.LabelFrame(left, text="Viewer", padding=6)
    v.pack(fill="x", pady=6)
    add_slider(v, "eye_offset", "Eye off axis", 0.0, 1.0, "{:.2f}")
    add_slider(v, "eye_z", "Eye z", -150, 60, "{:.0f}")
    add_slider(v, "fov", "Field of view", 10, 140, "{:.0f}°")
    aim_var = tk.BooleanVar(value=state["cfg"].aim_axis)
    ttk.Checkbutton(v, text="aim at tunnel axis (centres the mandala)",
                    variable=aim_var,
                    command=lambda: set_field("aim_axis", aim_var.get())
                    ).pack(anchor="w")

    # -- optics ------------------------------------------------------------
    o = ttk.LabelFrame(left, text="Optics", padding=6)
    o.pack(fill="x", pady=6)
    add_slider(o, "max_bounces", "Max bounces", 0, 64, "{:d}", step=1, cast=int)
    add_slider(o, "reflectivity", "Reflectivity", 0.4, 1.0, "{:.2f}")

    # -- subject -----------------------------------------------------------
    s = ttk.LabelFrame(left, text="Subject", padding=6)
    s.pack(fill="x", pady=6)
    add_slider(s, "object_size", "Image span", 10, 700, "{:.0f}")
    add_slider(s, "object_rot", "Rotate", 0, 360, "{:.0f}°")
    add_slider(s, "object_dx", "Pan x", -250, 250, "{:.0f}")
    add_slider(s, "object_dy", "Pan y", -250, 250, "{:.0f}")

    erow = ttk.Frame(s)
    erow.pack(fill="x", pady=(4, 0))
    ttk.Label(erow, text="Outside image", width=15).pack(side="left")
    edge_var = tk.StringVar(value=state["cfg"].edge_mode)
    ttk.Combobox(erow, textvariable=edge_var, state="readonly", width=10,
                 values=["black", "tile", "mirror", "clamp"]
                 ).pack(side="left", fill="x", expand=True, padx=4)
    edge_var.trace_add("write", lambda *_: set_field("edge_mode", edge_var.get()))

    orow = ttk.Frame(s)
    orow.pack(fill="x", pady=2)
    ttk.Label(orow, text="Outside wedge", width=15).pack(side="left")
    out_var = tk.StringVar(value=state["cfg"].outside_mode)
    out_box = ttk.Combobox(orow, textvariable=out_var, state="readonly",
                           width=10, values=["black", "object"])
    out_box.pack(side="left", fill="x", expand=True, padx=4)
    out_var.trace_add("write", lambda *_: set_field("outside_mode", out_var.get()))

    # -- schematic ---------------------------------------------------------
    sch = tk.Canvas(left, height=170, bg="#fbfbfd", highlightthickness=1,
                    highlightbackground="#ccc")
    sch.pack(fill="x", pady=(6, 6))

    # -- buttons -----------------------------------------------------------
    b = ttk.Frame(left)
    b.pack(fill="x")

    def do_load():
        path = filedialog.askopenfilename(
            title="Subject image",
            filetypes=[("Images", "*.png *.jpg *.jpeg *.bmp *.gif *.tif *.tiff *.webp"),
                       ("All files", "*.*")])
        if not path:
            return
        try:
            state["img"] = load_subject(path)
            state["subject"] = os.path.basename(path)
        except Exception as exc:
            messagebox.showerror("Load failed", str(exc))
            return
        schedule()

    def do_save():
        if state["frame"] is None:
            return
        path = filedialog.asksaveasfilename(defaultextension=".png",
                                            filetypes=[("PNG", "*.png")])
        if not path:
            return
        hi = replace(state["cfg"], supersample=2)
        Image.fromarray(render(hi, state["img"], 1400, 1400)).save(path)
        status.config(text=f"saved {path}")

    def do_reset():
        updating["lock"] = True
        state["cfg"] = Config()
        for name, var in vars_.items():
            var.set(float(getattr(state["cfg"], name)))
        mirror_var.set("2  (open wedge)")
        shape_var.set("rect")
        edge_var.set(state["cfg"].edge_mode)
        out_var.set(state["cfg"].outside_mode)
        aim_var.set(state["cfg"].aim_axis)
        updating["lock"] = False
        refresh_labels()
        draw_schematic()
        schedule()

    ttk.Button(b, text="Load image…", command=do_load).pack(side="left")
    ttk.Button(b, text="Save PNG…", command=do_save).pack(side="left", padx=4)
    ttk.Button(b, text="Reset", command=do_reset).pack(side="left")

    # -- reactive glue -----------------------------------------------------
    def apply_snap():
        if not snap_var.get() or state["cfg"].n_mirrors > 2:
            return
        target = state["cfg"].wedge_angle
        # snap to EVEN image counts only - those are the seamless wedges
        best = min((360.0 / n for n in range(2, 46, 2)),
                   key=lambda a: abs(a - target))
        updating["lock"] = True
        vars_["wedge_angle"].set(best)
        updating["lock"] = False
        set_field("wedge_angle", best)

    def on_mirrors(*_):
        n = int(mirror_var.get().split()[0])
        wedge = n <= 2
        updating["lock"] = True
        default_eye = 0.667 if wedge else 0.0
        vars_["eye_offset"].set(default_eye)
        updating["lock"] = False
        state["cfg"] = replace(state["cfg"], n_mirrors=n, eye_offset=default_eye)
        angle_sc.state(["!disabled"] if wedge else ["disabled"])
        out_box.state(["!disabled"] if wedge else ["disabled"])
        if wedge and snap_var.get():
            apply_snap()
        refresh_labels()
        draw_schematic()
        schedule()

    mirror_box.bind("<<ComboboxSelected>>", on_mirrors)

    def on_shape():
        if shape_var.get() == "rect":
            updating["lock"] = True
            vars_["taper"].set(1.0)
            updating["lock"] = False
            taper_sc.state(["disabled"])
            set_field("taper", 1.0)
        else:
            taper_sc.state(["!disabled"])
            if abs(state["cfg"].taper - 1.0) < 1e-6:
                vars_["taper"].set(1.8)
                set_field("taper", 1.8)
            else:
                refresh_labels()
    taper_sc.state(["disabled"])

    def refresh_labels():
        c = state["cfg"]
        if c.n_mirrors <= 2:
            n_img = c.images()
            r = c.rot_order()
            if c.is_exact():
                fold_lbl.config(
                    text=f"{round(n_img)} images · D{round(r)} symmetry "
                         f"({round(r)}-fold rotation) — seamless",
                    foreground="#2a6f2a")
            else:
                near = round(n_img)
                why = ("odd image count — last sector meets the first "
                       "flipped" if near % 2 else "not a whole number")
                fold_lbl.config(
                    text=f"360/{c.wedge_angle:.1f}° = {n_img:.2f} images — "
                         f"{why}, expect a seam",
                    foreground="#a3521b")
        else:
            n = c.n_mirrors
            if n == 3:
                txt = "equilateral tube — p6m tessellation, fills the field"
            elif n == 4:
                txt = "square tube — p4m tessellation, fills the field"
            else:
                txt = (f"{n}-gon tube — does not tile the plane exactly; "
                       "expect drift")
            fold_lbl.config(text=txt, foreground="#2a6f2a" if n in (3, 4)
                            else "#a3521b")

        if abs(c.taper - 1.0) < 1e-6:
            shape_note.config(text="")
        elif c.n_mirrors <= 2:
            shape_note.config(
                text="Wedge trapezoid: planes stay hinged on the axis, only the "
                     "outer edge tapers — changes where rays escape, so the "
                     "mandala's outer boundary stops being a plain circle.")
        else:
            shape_note.config(
                text="Tube trapezoid: the whole tube cones "
                     + ("out" if c.taper > 1 else "in")
                     + " — reflections curve, giving the spherical / domed "
                       "mandala instead of a flat tiling.")

    def draw_schematic():
        c = state["cfg"]
        sch.delete("all")
        w = sch.winfo_width() or 290
        h = 170
        pad = 12
        halfw = (w - 3 * pad) / 2

        # ---- cross section (left) ----
        cx = pad + halfw / 2
        cy = h / 2 + 6
        _, _, L = build_geometry(c)
        extent = max(aperture_half_width(c, 0, L), aperture_half_width(c, L, L),
                     c.width, 1e-3)
        k = (min(halfw, h - 30) * 0.45) / extent

        def poly_pts(z, scale=1.0):
            if c.n_mirrors <= 2:
                half = math.radians(c.wedge_angle) * 0.5
                wz = c.width + (c.width * c.taper - c.width) * z / L
                pts = [(0, 0),
                       (wz * math.cos(half), wz * math.sin(half)),
                       (wz * math.cos(half), -wz * math.sin(half))]
            else:
                tn = math.tan(math.pi / c.n_mirrors)
                rn = c.width / (2 * tn)
                rf = c.width * c.taper / (2 * tn)
                r = (rn + (rf - rn) * z / L) / math.cos(math.pi / c.n_mirrors)
                pts = []
                for i in range(c.n_mirrors):
                    a = 2 * math.pi * i / c.n_mirrors + math.pi / 2 + math.pi / c.n_mirrors
                    pts.append((r * math.cos(a), r * math.sin(a)))
            return [(cx + x * k * scale, cy - y * k * scale) for x, y in pts]

        if abs(c.taper - 1.0) > 1e-6:
            sch.create_polygon(poly_pts(L), outline="#b9c4d6", fill="",
                               dash=(3, 3), width=1)
        sch.create_polygon(poly_pts(0), outline="#3a6ea5", fill="#eaf1fa", width=2)
        ex = eye_position(c, L)[0]
        sch.create_oval(cx + ex * k - 3, cy - 3, cx + ex * k + 3, cy + 3,
                        fill="#d1495b", outline="")
        sch.create_text(cx, 12, text="cross-section (eye end)",
                        font=("TkDefaultFont", 7), fill="#666")

        # ---- side view (right) ----
        ox = pad * 2 + halfw
        avail_w = halfw
        sk = avail_w / max(L, 1e-3)
        vk = (h - 40) * 0.42 / extent
        cy2 = h / 2 + 6
        wn = aperture_half_width(c, 0, L)
        wf = aperture_half_width(c, L, L)
        sch.create_polygon(ox, cy2 - wn * vk, ox + L * sk, cy2 - wf * vk,
                           ox + L * sk, cy2 + wf * vk, ox, cy2 + wn * vk,
                           outline="#3a6ea5", fill="#eaf1fa", width=2)
        sch.create_line(ox, cy2, ox + L * sk, cy2, fill="#aab", dash=(2, 3))
        sch.create_line(ox + L * sk, cy2 - (h / 2 - 12), ox + L * sk,
                        cy2 + (h / 2 - 12), fill="#7a9a4a", width=3)
        eyx = ox + min(max(c.eye_z, -L * 0.4), L) * sk
        sch.create_oval(eyx - 3, cy2 - ex * vk - 3, eyx + 3, cy2 - ex * vk + 3,
                        fill="#d1495b", outline="")
        sch.create_text(ox + avail_w / 2, 12,
                        text=f"side view   L={c.length:.0f}  W={c.width:.0f}",
                        font=("TkDefaultFont", 7), fill="#666")
        sch.create_text(ox + L * sk - 2, h - 8, text="subject", anchor="e",
                        font=("TkDefaultFont", 7), fill="#7a9a4a")

    sch.bind("<Configure>", lambda _e: draw_schematic())

    # -- result pump -------------------------------------------------------
    def pump():
        got = None
        while True:
            try:
                got = results.get_nowait()
            except queue.Empty:
                break
        if got is not None:
            if got[0] == "error":
                status.config(text=f"render error: {got[1]}")
            else:
                _, frame, final = got
                state["frame"] = frame
                cw = max(view.winfo_width(), 64)
                chh = max(view.winfo_height(), 64)
                side = min(cw, chh)
                im = Image.fromarray(frame)
                if im.width != side:
                    im = im.resize((side, side),
                                   Image.LANCZOS if final else Image.NEAREST)
                state["photo"] = ImageTk.PhotoImage(im)
                view.delete("all")
                view.create_image(cw // 2, chh // 2, image=state["photo"])
                c = state["cfg"]
                sym = (f"{round(c.images())} images · D{round(c.rot_order())}"
                       if c.n_mirrors <= 2 and c.is_exact()
                       else (f"{c.images():.2f} images (seam)" if c.n_mirrors <= 2
                             else f"{c.n_mirrors}-mirror tube"))
                status.config(
                    text=f"{state['subject']}   |   {sym}   |   "
                         f"L={c.length:.0f} W={c.width:.0f} "
                         f"taper={c.taper:.2f}   |   "
                         f"{'full' if final else 'preview'} {frame.shape[1]}px")
        root.after(30, pump)

    refresh_labels()
    root.after(60, lambda: (draw_schematic(), request(True)))
    root.after(30, pump)
    root.mainloop()


# ---------------------------------------------------------------------------
# headless helpers
# ---------------------------------------------------------------------------

GRID_SWEEPS = {
    "wedge_angle": [90, 72, 60, 51.43, 45, 36, 30, 22.5, 18],
    "length": [20, 40, 60, 90, 120, 160, 220, 300, 400],
    "width": [10, 18, 26, 34, 45, 60, 80, 110, 150],
    "taper": [0.25, 0.4, 0.6, 0.8, 1.0, 1.3, 1.7, 2.2, 3.0],
    "max_bounces": [0, 1, 2, 3, 5, 8, 13, 24, 48],
    "eye_offset": [0.0, 0.15, 0.3, 0.45, 0.55, 0.667, 0.78, 0.88, 0.97],
}


def render_grid(cfg: Config, img: np.ndarray, field: str, out: str,
                tile: int = 340) -> None:
    from PIL import Image, ImageDraw
    values = GRID_SWEEPS[field]
    cols = 3
    rows = math.ceil(len(values) / cols)
    sheet = Image.new("RGB", (cols * tile, rows * tile), (12, 12, 16))
    draw = ImageDraw.Draw(sheet)
    for i, v in enumerate(values):
        c = replace(cfg, **{field: type(getattr(cfg, field))(v)})
        frame = render(c, img, tile, tile)
        sheet.paste(Image.fromarray(frame), ((i % cols) * tile, (i // cols) * tile))
        label = f"{field} = {v}"
        if field == "wedge_angle":
            nimg = 360 / v
            tag = (f"D{round(180 / v)} seamless" if abs(nimg - round(nimg)) < 0.02
                   and round(nimg) % 2 == 0 else "odd/seam")
            label += f"   ({nimg:.0f} images, {tag})"
        draw.text(((i % cols) * tile + 8, (i // cols) * tile + 8), label,
                  fill=(255, 255, 255))
        print(f"  {label}")
    sheet.save(out)
    print(f"wrote {out}")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("image", nargs="?", help="subject image (omit for a synthetic one)")
    ap.add_argument("--render", metavar="PNG", help="render once and exit")
    ap.add_argument("--grid", choices=sorted(GRID_SWEEPS),
                    help="render a 3x3 contact sheet sweeping one parameter")
    ap.add_argument("--out", default="kaleido_grid.png", help="output for --grid")
    ap.add_argument("--size", type=int, default=900)
    ap.add_argument("--mirrors", type=int, default=2)
    ap.add_argument("--angle", type=float, default=60.0)
    ap.add_argument("--length", type=float, default=120.0)
    ap.add_argument("--width", type=float, default=45.0)
    ap.add_argument("--taper", type=float, default=1.0)
    ap.add_argument("--bounces", type=int, default=24)
    ap.add_argument("--object-size", type=float, default=180.0)
    args = ap.parse_args(argv)

    if args.image:
        img = load_subject(args.image)
        name = os.path.basename(args.image)
    else:
        img = synthetic_subject()
        name = "synthetic subject"

    cfg = Config(n_mirrors=args.mirrors, wedge_angle=args.angle,
                 length=args.length, width=args.width, taper=args.taper,
                 max_bounces=args.bounces, object_size=args.object_size,
                 eye_offset=0.667 if args.mirrors <= 2 else 0.0)

    if args.grid:
        render_grid(cfg, img, args.grid, args.out)
        return 0
    if args.render:
        from PIL import Image
        Image.fromarray(render(replace(cfg, supersample=2), img,
                               args.size, args.size)).save(args.render)
        print(f"wrote {args.render}")
        return 0

    run_gui(cfg, img, name)
    return 0


if __name__ == "__main__":
    sys.exit(main())

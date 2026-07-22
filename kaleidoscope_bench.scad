// ==========================================================================
//  Kaleidoscope / Optical Bench Module  -  parametric printable parts
//  Implements the mechanical ideas from redme.md:
//    * modular rod/rail carriage system ("breadboard for optics")
//    * adjustable-angle front-surface mirror wedge (2-fold ... 12-fold symmetry)
//    * camera carriage (webcam / 1-4"-20) that sits at the mirror vertex
//    * motorized subject-stage turntable (NEMA-11 + 608 bearing, geared)
//    * swappable subject dish (oil/water/dye or beads)
//    * WS2812 LED-ring backlight holder
//
//  Pick a part with `part` (or "all" to lay them out for a look).
//  Units: millimetres. Hardware: M3 screws, 608 bearing, NEMA-11 stepper,
//  3 mm rod for the hinge pin, front-surface acrylic mirror strips.
// ==========================================================================

// part = "all";
part = "asm_full";
// options:
//   "carriage"       generic rod-clamp carriage (the rail building block)
//   "mirror_tray_a"  one mirror channel (hinge phase A) - print this
//   "mirror_tray_b"  the mating mirror channel (hinge phase B) - print this
//   "angle_gauge"    drop-in wedge that sets the included mirror angle
//   "wedge_yoke"     cradles the wedge's outer edges + bolts to the bridge
//   "tri_bracket"    3-mirror equilateral bracket (full-tessellation head)
//   "tri_bracket_top" 3-mirror top bracket with the bridge mount grid
//   "tri_head"       3-mirror head preview (3 mirrors + 2 brackets)
//   "wedge_asm"      both mirrors folded to `wedge_angle` (preview only)
//   "camera_mount"   webcam / tripod-screw carriage for the vertex
//   "turntable_base" stepper bracket + 608 bearing boss (subject drive)
//   "rail_foot"      bolt-on foot that clamps a rail end to a chassis board
//   "rail_bridge"    clamps both rails, carries the wedge + camera over the dish
//   "platter"        geared turntable platter (rides the bearing)
//   "drive_pulley"   grooved round-belt pulley for the stepper shaft
//   "subject_dish"   shallow tray for oil/water/dye or beads
//   "led_ring"       WS2812 ring / backlight holder
//   "enclosure"      electronics box under the base (power/rocker/pot cutouts)
//   "all"            everything, scattered on the bed
//   --- assembly / interaction views (not for printing) ---
//   "asm_turntable"  base+bearing+platter+pulley+belt+stepper+dish+led
//   "asm_wedge"      the two mirror trays + hinge pin + mirrors + gauge
//   "asm_rail"       a carriage clamped on a rod (+ camera)
//   "asm_full"       rough overview of the whole vertical instrument

explode = 0;   // [0:0.05:1]  0 = assembled, 1 = fully separated (asm_* views)
               // Window > Customizer gives a slider. Press Animate -> gears spin ($t).
head = "wedge";// which head asm_full hangs: "wedge" = adjustable centred mandala
               // on black; "tri" = full-field tessellation. See "KALEIDOSCOPE
               // HEADS" note below for the difference & when to use each.

$fn = 64;

/* ---------------- rod / rail ---------------- */
rod_d = 8;      // smooth-rod diameter (set 25.4 for 1" rail, 6/10/12 also common)
fit   = 0.4;    // clearance added to bores/pockets

/* ---------------- mirror wedge -------------- */
wedge_len   = 120;  // tunnel length (mirror length, along the optical axis)
mirror_w    = 45;   // mirror width, out from the vertex
mirror_t    = 2;    // front-surface mirror strip thickness
back_t      = 3;    // tray backing thickness
lip         = 2.5;  // retaining lip
wedge_angle = 60;   // INCLUDED angle -> images = 360/angle:
                    // 90->4  60->6  45->8  36->10  30->12 (must divide 360)
knuckle_d   = 6;    // hinge knuckle diameter
pin_d       = 3;    // hinge pin (3 mm rod / filament)
seg         = 16;   // hinge knuckle segment length

/* ---------------- stepper (NEMA-11) --------- */
nema_body  = 28;    // face size (square)
nema_holes = 23;    // mounting-hole spacing (square pattern)
nema_hole_d= 2.7;   // M2.5 clearance
nema_pilot = 22.5;  // raised pilot boss diameter
nema_shaft = 5;     // shaft diameter

/* ---------------- 608 bearing --------------- */
brg_od = 22; brg_id = 8; brg_th = 7;

/* ---------------- turntable belt drive ------ */
//  Round rubber belt in V-grooves (belt-drive turntable, like a record player):
//  silent, self-tensioning (elastic), no printed teeth. Reduction ~ platter/pulley.
platter_od   = 140;  // platter outer diameter (belt rides a V-groove in the rim)
belt_dia     = 4;    // round drive-belt cross-section (3-5 mm nitrile round belt)
pulley_od    = 20;   // stepper drive-pulley OD -> reduction ~ platter_od/pulley_od (7:1)
drive_gap    = 3;    // clearance between pulley and platter rims
groove_th    = 8;    // rim / pulley height (the V-groove sits mid-height)
base_th      = 6;

/* ---------------- dish / LED ---------------- */
dish_od    = 110; dish_depth = 14;
led_ring_od= 66;  led_ring_id= 50;   // typical 24-LED WS2812 ring footprint

/* ---------------- rail-to-base mounting ----- */
rail_foot_r   = 86;   // radius from turntable centre to each vertical rail
                      // (must clear the platter rim: > platter_od/2)
rail_span_ang = 60;   // angular gap between the two rails (centred opposite the stepper)
rail_len      = 220;  // vertical rail (rod) length

/* ---------------- electronics enclosure ----- */
encl_wall   = 2.4;     // wall & floor thickness
encl_h      = 52;      // interior depth below the base plate (fits NEMA-11 + driver)
panel_z     = 26;      // height of the panel components above the interior floor
jack_d      = 8.0;     // DC barrel-jack panel hole (threaded 8 mm type; 11-12 for bigger)
rocker_cut  = [21,15]; // rocker-switch snap-in cutout (KCD1-style) - match your switch
pot_d       = 7.2;     // potentiometer bushing hole (9 mm pot)
pot_tab_d   = 3.4;     // pot anti-rotation tab hole
pot_tab_off = 7;       // tab offset above the shaft centre
usb_cut     = [10, 5.5];// USB-C panel slot [W,H] (for a XIAO port or a panel coupler)
usb_z       = 16;      // USB-C centre height above the floor

// --------------------------------------------------------------------------
//  helpers
// --------------------------------------------------------------------------
function car_h(top_th)   = (8 + (rod_d+fit)/2) + (rod_d+fit)/2 + top_th;
function knuckles(side)  = [ for(i=[0:1:floor(wedge_len/seg)-1]) if((i%2)==side) [i*seg, seg-0.8] ];

module ring(ri, ro, h){
    difference(){ cylinder(r=ro, h=h); translate([0,0,-0.1]) cylinder(r=ri, h=h+0.2); }
}

// Belt-drive centre distance (stepper pulley to platter centre).
function drive_cd() = platter_od/2 + drive_gap + pulley_od/2;

// V-groove cut for a round belt: revolve a triangular notch into a rim at
// radius R, centred at height zc. The round belt wedges into the V and grips.
module v_groove_cut(R, zc, bd){
    gw = bd*1.25;   // groove opening width
    gd = bd*0.85;   // groove depth
    rotate_extrude($fn=140)
        polygon([[R+0.6, zc+gw/2], [R-gd, zc], [R+0.6, zc-gw/2]]);
}

// --------------------------------------------------------------------------
//  1. Rail carriage  -  split clamp that grips the rod, flat top for mounting
// --------------------------------------------------------------------------
module carriage(len=30, w=44, top_th=8){
    rb = (rod_d+fit)/2;
    zc = 8 + rb;                 // rod-bore centre height
    H  = zc + rb + top_th;
    difference(){
        cube([w, len, H]);
        // rod bore (along the rail axis, Y)
        translate([w/2,-1,zc]) rotate([-90,0,0]) cylinder(d=rod_d+fit, h=len+2);
        // split slot up into the bore -> two clamping jaws
        translate([w/2-0.8,-1,0]) cube([1.6, len+2, zc]);
        // clamp screw across the jaws (M3), with head recess + nut trap
        translate([-1,   len/2, 4]) rotate([0,90,0]) cylinder(d=3.4, h=w+2);
        translate([-1,   len/2, 4]) rotate([0,90,0]) cylinder(d=6.4, h=4,  $fn=6);
        translate([w-5,  len/2, 4]) rotate([0,90,0]) cylinder(d=6.4, h=6,  $fn=6);
        // top mounting grid (M3) for whatever bolts on
        for(ix=[-1,1], iy=[-1,1])
            translate([w/2+ix*12, len/2+iy*(len/2-8), H-9]) cylinder(d=3.2, h=10);
    }
}

// --------------------------------------------------------------------------
//  1b. Rail socket / foot  -  grips a vertical rod end and ties it to the
//      base. `rail_socket` is the collar reused by the turntable base;
//      `rail_foot` puts it on a bolt-down flange for a separate baseboard.
// --------------------------------------------------------------------------
module rail_socket(h=26){
    oc = rod_d+9;                                   // collar OD
    difference(){
        cylinder(d=oc, h=h, $fn=48);
        translate([0,0,-1]) cylinder(d=rod_d+fit, h=h+2);              // rod bore (through)
        translate([-0.9, 0, 4]) cube([1.8, oc/2+1, h]);                // clamp slit to the +Y edge
        // pinch bolt across the two jaws (M3 + nut) squeezes the bore
        translate([-oc, oc*0.28, h*0.5]) rotate([0,90,0]) cylinder(d=3.4, h=2*oc, $fn=24);
        translate([ oc/2-2.4, oc*0.28, h*0.5]) rotate([0,90,0]) cylinder(d=6.3, h=3, $fn=6);  // nut trap
        translate([-oc/2-0.6, oc*0.28, h*0.5]) rotate([0,90,0]) cylinder(d=6.3, h=3);         // head recess
    }
}
module rail_foot(){
    fw=42; fd=30; ft=6;
    difference(){
        union(){
            translate([-fw/2,-fd/2,0]) cube([fw, fd, ft]);            // bolt-down flange
            translate([0,0,ft]) rail_socket();
        }
        for(x=[-1,1]) translate([x*15,0,-1])   cylinder(d=3.6, h=ft+2);   // M3 bolt-down
        for(x=[-1,1]) translate([x*15,0,ft-3]) cylinder(d=6.6, h=4);      // counterbores
    }
}

// --------------------------------------------------------------------------
//  1c. Rail bridge  -  clamps BOTH vertical rails and cantilevers a mounting
//      platform over the dish centre. Slides up/down the rails and locks with
//      two M3 pinch bolts. The platform has a central optical bore + an M3
//      grid: bolt the mirror wedge under it and/or a camera plate on top.
//      Auto-places its clamp bores at the same rail positions as the base.
// --------------------------------------------------------------------------
module bridge_clamp_cut(p, ang, th, ch, oc){
    translate([p[0],p[1],0]) rotate([0,0,ang]){
        translate([0,0,-1]) cylinder(d=rod_d+fit, h=th+ch+2);                       // rail bore
        translate([-0.9,0,th+3]) cube([1.8, oc/2+1, ch]);                           // clamp slit
        translate([-oc, oc*0.28, th+ch*0.5]) rotate([0,90,0]) cylinder(d=3.4,h=2*oc);        // pinch bolt
        translate([oc/2-2.4, oc*0.28, th+ch*0.5]) rotate([0,90,0]) cylinder(d=6.3,h=3,$fn=6);// nut trap
    }
}
module rail_bridge(){
    fa = [180 - rail_span_ang/2, 180 + rail_span_ang/2];
    p1 = [rail_foot_r*cos(fa[0]), rail_foot_r*sin(fa[0])];
    p2 = [rail_foot_r*cos(fa[1]), rail_foot_r*sin(fa[1])];
    xr = p1[0];  ys = abs(p1[1]);
    th=8; oc=rod_d+9; ch=26; plat=52; rib=14;
    difference(){
        union(){
            linear_extrude(th) hull(){ translate(p1) circle(d=oc); translate(p2) circle(d=oc); } // crossbar
            linear_extrude(th) hull(){ translate([xr,0]) circle(d=oc); square(plat, center=true); } // arm+platform
            translate([p1[0],p1[1],0]) cylinder(d=oc, h=th+ch, $fn=48);              // collars
            translate([p2[0],p2[1],0]) cylinder(d=oc, h=th+ch, $fn=48);
            translate([xr-3, -ys-oc/2, th-0.01]) cube([6, 2*ys+oc, rib]);            // crossbar rib
            translate([xr, -3, th-0.01]) cube([abs(xr)-plat/2, 6, rib]);             // arm rib (stops at platform)
        }
        bridge_clamp_cut(p1, fa[0], th, ch, oc);
        bridge_clamp_cut(p2, fa[1], th, ch, oc);
        translate([0,0,-1]) cylinder(d=28, h=th+2);                                  // optical bore
        for(x=[-1,1],y=[-1,1]) translate([x*20,y*20,-1]) cylinder(d=3.2, h=th+2);    // M3 mount grid
    }
}

// ==========================================================================
//  KALEIDOSCOPE HEADS  -  two interchangeable optics, DIFFERENT images.
//  Both bolt to the same rail bridge; pick with `head` (asm_full) or print
//  the parts you want. They are NOT prototype vs final - they look different.
//
//  2-MIRROR WEDGE (mirror_tray x2 + angle_gauge + wedge_yoke)
//    Image : a single centred, radially-symmetric MANDALA / rosette sitting
//            on a BLACK surround (the reflected circle doesn't fill a
//            rectangular frame's corners - that black is intrinsic, not a
//            defect or a seam).
//    Symmetry : 360/angle sectors -> 90=4, 60=6, 45=8, 36=10, 30=12.
//    Illusion : seamless AS LONG AS the angle divides 360 exactly. An angle
//               that doesn't divide 360 leaves a mismatched sector - that
//               is the only thing that "breaks" it (hence the fixed gauge).
//    Why use it : the angle is ADJUSTABLE, so you can change the fold count
//               live - the one thing the triangle can't do. Also the classic
//               centred-mandala aesthetic (black keys out easily in a mixer).
//
//  3-MIRROR TRIANGLE (tri_bracket x2 + tri_bracket_top + 3 mirror strips)
//    Image : FULL-FIELD tessellation - the cell repeats edge to edge across
//            the whole frame, no black anywhere (an "infinite wallpaper").
//    Symmetry : fixed by the triangle. Equilateral (60-60-60) = hexagonal
//               tiling. 30-60-90 and 45-45-90 also tile perfectly but need
//               different brackets; other triangles tile imperfectly.
//    Why use it : fills the entire frame with pattern - usually the better
//               feed for the video/glitch chain (no dead black area to mask).
//
//  Rule of thumb: TRIANGLE for full-frame texture; WEDGE for an adjustable
//  centred mandala. Default head = "wedge" (adjustable); set "tri" for tiling.
// ==========================================================================

// --------------------------------------------------------------------------
//  2. Mirror wedge  -  two hinged channels + a drop-in angle gauge
//     Hinge runs the full length along the vertex (out of the light path);
//     the gauge sets the included angle. Print tray A + tray B, interleave
//     the knuckles, push a 3 mm pin down the vertex, drop in a gauge, band it.
// --------------------------------------------------------------------------
module mirror_tray(side=0){
    difference(){
        union(){
            cube([mirror_w, wedge_len, back_t]);                                   // backing
            translate([mirror_w-lip,0,0]) cube([lip, wedge_len, back_t+mirror_t+0.6]); // outer lip
            for(y=[0, wedge_len-lip])                                              // end corner tabs
                translate([mirror_w-lip*2, y, 0]) cube([lip*2, lip, back_t+mirror_t+0.6]);
            for(k=knuckles(side))                                                  // hinge knuckles
                translate([0, k[0], back_t/2]) rotate([-90,0,0]) cylinder(d=knuckle_d, h=k[1]);
        }
        // hinge pin bore down the vertex
        translate([0,-1,back_t/2]) rotate([-90,0,0]) cylinder(d=pin_d+0.5, h=wedge_len+2);
    }
}

// Wedge insert: isosceles prism whose apex angle == the included mirror angle.
// Slip it in at one end near the vertex to open the mirrors to that angle.
module angle_gauge(theta=wedge_angle, L=14){
    r = mirror_w-4;
    difference(){
        linear_extrude(L)
            polygon([[0,0],
                     [r*cos(theta/2),  r*sin(theta/2)],
                     [r*cos(theta/2), -r*sin(theta/2)]]);
        translate([r*0.45,0,-1]) cylinder(d=4, h=L+2);   // lighten / rubber-band peg hole
    }
}

// Preview only: fold both trays to wedge_angle about the vertex line.
module wedge_asm(){
    hz = back_t/2;
    color("SkyBlue")   translate([0,0,hz]) rotate([0,-wedge_angle/2,0]) translate([0,0,-hz]) mirror_tray(0);
    color("LightSteelBlue") translate([0,0,hz]) rotate([0, wedge_angle/2,0]) translate([0,0,-hz]) mirror_tray(1);
    color("Salmon")    translate([0, wedge_len/2+7, hz]) rotate([90,0,0]) angle_gauge();
}

// --------------------------------------------------------------------------
//  2b. Wedge yoke  -  cradles the wedge's two outer edges and bolts up to the
//      rail bridge (matches its M3 grid + optical bore), hanging the tunnel
//      over the dish. Sets the angle like the gauge; open centre for the
//      camera; an M3 set screw locks each tray. Regenerate if wedge_angle
//      changes (grips sit at +-wedge_angle/2, same as the gauge).
// --------------------------------------------------------------------------
module tray_grip(gy=20){                    // captures one tray's outer edge (unrotated frame)
    difference(){
        translate([mirror_w-8,   0,  -3]) cube([13, gy, 13]);
        translate([mirror_w-8.5,-1,-0.3]) cube([9, gy+2, 6.3]);        // tray pocket
        translate([mirror_w-1.5, gy/2, -4]) cylinder(d=2.6, h=6);       // M3 set screw (tap)
    }
}
module wedge_yoke(){
    a  = wedge_angle/2;  hz = back_t/2;  fY = 6;  r = mirror_w-4;
    acx = 2*mirror_w*cos(a)/3;            // aperture centroid -> centres the bridge grid
    x0 = 12;  zt = x0*tan(a);  gy = 20;
    difference(){
        union(){
            translate([-6, 0, hz-26]) cube([54, fY, 52]);              // flange to the bridge
            for(s=[-1,1])                                              // grips at +-wedge_angle/2
                translate([0,fY-1,0]) translate([0,0,hz]) rotate([0,s*a,0]) translate([0,0,-hz]) tray_grip(gy);
        }
        for(x=[-20,20], z=[-20,20])                                    // bridge M3 grid
            translate([acx+x,-1,hz+z]) rotate([-90,0,0]) cylinder(d=3.4, h=fY+2);
        translate([0,-1,hz]) rotate([-90,0,0]) linear_extrude(fY+2)    // open camera aperture
            polygon([[x0,-zt],[r*cos(a),-r*sin(a)],[r*cos(a),r*sin(a)],[x0,zt]]);
    }
}

// --------------------------------------------------------------------------
//  2c. Three-mirror head  -  an equilateral triangular tube (full tessellation,
//      not just the 2-mirror wedge). Three mirror strips glue to the inner faces
//      of triangular brackets; use two or three brackets along the length. The
//      top bracket (mount=true) carries the bridge M3 grid so the whole tube
//      hangs from the bridge, aperture centred on the optical bore.
//      Mirror strip size: mirror_w wide x wedge_len long x mirror_t thick (x3).
// --------------------------------------------------------------------------
function tri_ri() = mirror_w/(2*sqrt(3));                      // aperture inradius
module tri2d(inr){ R=2*inr; polygon([for(k=[0:2]) [R*cos(90+120*k), R*sin(90+120*k)]]); }
module tri_bracket(mount=false){
    t = 8;  fw = 7;  ri = tri_ri();
    difference(){
        union(){
            linear_extrude(t) difference(){ tri2d(ri+mirror_t+fw); tri2d(ri+mirror_t); }   // frame ring
            if(mount) linear_extrude(t) difference(){ offset(4) square(46, center=true); tri2d(ri); } // mount pad
        }
        if(mount) for(x=[-20,20], y=[-20,20]) translate([x,y,-1]) cylinder(d=3.4, h=t+2);   // bridge grid
    }
}
// preview: 3 mirrors + top(mount) & bottom brackets, tunnel along +Z
module tri_head(){
    ri = tri_ri();
    color("Plum")      translate([0,0,wedge_len-8]) tri_bracket(mount=true);   // top -> bridge
    color("MediumPurple")                          tri_bracket(mount=false);   // bottom
    for(k=[0:2]) rotate([0,0,120*k]) color([0.75,0.87,0.95,0.95])
        translate([-mirror_w/2, -ri-mirror_t, 0]) cube([mirror_w, mirror_t, wedge_len]);
}
module tri_head_hung(){ translate([0,0,-wedge_len]) tri_head(); }             // top bracket at Z=0

// --------------------------------------------------------------------------
//  3. Camera mount  -  carriage + upright plate (1-4"-20 + zip-tie webcam)
// --------------------------------------------------------------------------
module camera_mount(){
    th=8; len=34; w=46;
    carriage(len=len, w=w, top_th=th);
    H  = car_h(th);
    pw=54; ph=58; pt=5;
    translate([w/2-pw/2, len/2-pt/2, H])
        difference(){
            cube([pw, pt, ph]);
            translate([pw/2-2,-1,12]) cube([4, pt+2, ph-24]);                     // height-adjust slot
            translate([pw/2, pt+1, ph/2]) rotate([90,0,0]) cylinder(d=6.6, h=pt+2); // 1/4"-20 clearance
            for(z=[16,ph-16], x=[-18,18])                                          // webcam zip-tie holes
                translate([pw/2+x,-1,z]) rotate([-90,0,0]) cylinder(d=3.6, h=pt+2);
        }
    translate([w/2-16, len/2-pt/2, H]) cube([32, 14, 3]);                          // rest shelf
}

// --------------------------------------------------------------------------
//  4. Turntable base  -  608 bearing boss + NEMA-11 bracket, geared drive
//     Mount on >=35 mm standoffs (or the enclosure posts) so the stepper body
//     hangs clear underneath. Rails mount separately via rail_foot on a board.
// --------------------------------------------------------------------------
module turntable_base(){
    cd = drive_cd();    // stepper-pulley centre distance
    difference(){
        union(){
            translate([0,0,-base_th]) linear_extrude(base_th)
                hull(){ circle(brg_od/2+14); translate([cd,0]) circle(nema_body/2+9); }
            translate([0,0,-(brg_th+2)]) cylinder(d=brg_od+8, h=brg_th+2);         // bearing hub
        }
        translate([0,0,-brg_th])    cylinder(d=brg_od+0.2, h=brg_th+0.3);          // bearing pocket
        translate([0,0,-(brg_th+3)])cylinder(d=brg_id+3,  h=brg_th+4);            // centre clearance
        translate([cd,0,0]){                                                       // stepper
            translate([0,0,-(base_th+1)]) cylinder(d=nema_pilot+0.6, h=base_th+2); // pilot/shaft
            for(x=[-1,1], y=[-1,1])
                translate([x*nema_holes/2, y*nema_holes/2, -(base_th+1)]) cylinder(d=nema_hole_d, h=base_th+2);
        }
        for(a=[120,200,320]) rotate([0,0,a])                                       // standoff / post holes
            translate([brg_od/2+10,0,-(base_th+1)]) cylinder(d=3.4, h=base_th+2);
    }
}

// --------------------------------------------------------------------------
//  5. Platter  -  smooth disk with a round-belt V-groove in the rim and a hub
//     that presses into the 608. No teeth: the belt drives it by friction.
// --------------------------------------------------------------------------
module platter(){
    R = platter_od/2;
    difference(){
        union(){
            cylinder(r=R, h=groove_th);                                             // rim (holds the belt groove)
            translate([0,0,groove_th-0.01]) cylinder(r=R-3, h=4);                   // solid top
            translate([0,0,-6])             cylinder(d=brg_id, h=6.2);              // hub -> bearing ID
            translate([0,0,groove_th+4-0.01]) ring(dish_od/2-2, dish_od/2, 3);      // dish register rim
        }
        v_groove_cut(R, groove_th/2, belt_dia);                                     // round-belt V-groove
        translate([0,0,-7]) cylinder(d=3.2, h=groove_th+4+12);                      // optional axle screw
    }
}

// --------------------------------------------------------------------------
//  6. Drive pulley  -  grooved pulley on the stepper shaft; the round belt
//     wraps it and the platter rim. Self-tensioning, so no idler needed.
// --------------------------------------------------------------------------
module drive_pulley(){
    R = pulley_od/2;
    difference(){
        cylinder(r=R, h=groove_th);
        v_groove_cut(R, groove_th/2, belt_dia);                                    // belt groove
        translate([0,0,-0.1]) cylinder(d=nema_shaft+0.3, h=groove_th+0.2);         // shaft bore
        translate([0,-R-1, groove_th/2]) rotate([-90,0,0]) cylinder(d=2.5, h=R+2); // M3 set screw (tap)
    }
}

// --------------------------------------------------------------------------
//  7. Subject dish  -  print floor thin + translucent for backlighting;
//     seal with silicone if you run oil/water/dye.
// --------------------------------------------------------------------------
module subject_dish(){
    wall=2.5; floor=1.2;
    difference(){
        cylinder(d=dish_od, h=dish_depth);
        translate([0,0,floor]) cylinder(d=dish_od-2*wall, h=dish_depth);
    }
    translate([0,0,-3]) ring(dish_od/2-4, dish_od/2-1.5, 3);                        // register foot
}

// --------------------------------------------------------------------------
//  8. LED ring holder  -  seats a WS2812 ring, open centre passes light
// --------------------------------------------------------------------------
module led_ring(){
    od = led_ring_od+8;
    difference(){
        cylinder(d=od, h=6);
        translate([0,0,3]) ring(led_ring_id/2-0.3, led_ring_od/2+0.4, 3.5);        // ring pocket (from top)
        cylinder(d=led_ring_id-6, h=7);                                            // light window
        translate([-od/2,-3,1]) cube([od,6,4]);                                    // wire channel
        for(a=[0,120,240]) rotate([0,0,a]) translate([od/2-3,0,0]) cylinder(d=3.2, h=7); // mount holes
    }
}

// --------------------------------------------------------------------------
//  9. Electronics enclosure  -  box that hangs under the drive base and holds
//     the stepper + driver/controller + power. Open top: the turntable base
//     IS the lid and bolts to the three internal posts (its standoff holes).
//     Front (-Y) wall carries: DC power jack | rocker switch | potentiometer.
// --------------------------------------------------------------------------
module enclosure(){
    w   = encl_wall;
    cd  = drive_cd();
    ix0 = -brg_od/2 - 22;              // interior X min (room behind the bearing)
    ix1 = cd + nema_body/2 + 12;       // interior X max (past the stepper)
    iyh = 33;                          // interior Y half-width
    topZ = -base_th;                   // interior top = base underside
    botZ = topZ - encl_h;              // interior floor
    px  = [ix0+22, ix0+52, ix0+82];    // panel component X positions (kept off the stepper)
    pz  = botZ + panel_z;
    difference(){
        translate([ix0-w, -iyh-w, botZ-w]) cube([(ix1-ix0)+2*w, 2*iyh+2*w, encl_h+w]);  // outer shell
        translate([ix0, -iyh, botZ])       cube([ix1-ix0, 2*iyh, encl_h+2]);            // cavity, open top
        // --- front (-Y) panel cutouts ---
        translate([px[0], -iyh-w-1, pz]) rotate([-90,0,0]) cylinder(d=jack_d, h=w+2);                    // power jack
        translate([px[1]-rocker_cut[0]/2, -iyh-w-1, pz-rocker_cut[1]/2]) cube([rocker_cut[0], w+2, rocker_cut[1]]); // rocker
        translate([px[2], -iyh-w-1, pz])            rotate([-90,0,0]) cylinder(d=pot_d,     h=w+2);      // pot bushing
        translate([px[2], -iyh-w-1, pz+pot_tab_off])rotate([-90,0,0]) cylinder(d=pot_tab_d, h=w+2);      // pot anti-rotation tab
        // --- USB-C on the -X end wall (near the controller) ---
        translate([ix0-w-1, -usb_cut[0]/2, botZ+usb_z-usb_cut[1]/2]) cube([w+2, usb_cut[0], usb_cut[1]]);
        // --- stepper-wire slot (back wall) + floor vents ---
        translate([cd-8, iyh-1, botZ+10]) cube([16, w+2, 10]);
        for(i=[-2:2]) translate([(ix0+ix1)/2 + i*13 - 3, -16, botZ-w-1]) cube([6, 32, w+2]);
    }
    // base-mounting posts (base's 3 standoff holes bolt down into these)
    for(a=[120,200,320]) rotate([0,0,a]) translate([brg_od/2+10, 0, botZ])
        difference(){ cylinder(d=8, h=encl_h); translate([0,0,encl_h-9]) cylinder(d=2.9, h=10); }
    // anti-sag support posts under the base neck (no screw)
    for(y=[-15,15]) translate([55, y, botZ]) cylinder(d=7, h=encl_h);
}

// ==========================================================================
//  ASSEMBLY / INTERACTION VIEWS
//  These place the printed parts (plus stand-ins for the bought hardware) in
//  their real relative positions so you can see how things fit and move.
//  `explode` slides parts apart along their assembly axes; `$t` (Animate)
//  spins the turntable and its gears.
// ==========================================================================

// ---- stand-ins for bought hardware (NOT printed) ----
module rep_bearing(){ color("Gainsboro") ring(brg_id/2, brg_od/2, brg_th); }
module rep_stepper(){                                   // origin = top face / shaft base
    color("DimGray") translate([-nema_body/2,-nema_body/2,-31]) cube([nema_body,nema_body,31]);
    color("Silver")  cylinder(d=nema_pilot, h=1.8);     // pilot boss
    color("Silver")  cylinder(d=nema_shaft, h=18);      // shaft
}
module rep_rod(len){ color("SteelBlue")  rotate([-90,0,0]) cylinder(d=rod_d, h=len); }
module rep_rod_v(len){ color("SteelBlue") cylinder(d=rod_d, h=len); }        // vertical rail
function board_z() = -(base_th + encl_h + encl_wall);                         // chassis board level
module rep_board(){                                                           // user-supplied baseboard
    cd = drive_cd();
    fa = [180-rail_span_ang/2, 180+rail_span_ang/2];
    translate([0,0,board_z()-4]) linear_extrude(4) offset(12) hull(){
        translate([(cd-8)/2,0]) square([cd+70, 74], center=true);
        for(a=fa) translate([rail_foot_r*cos(a), rail_foot_r*sin(a)]) circle(12);
    }
}
module rep_pin(len){ color("Goldenrod")  rotate([-90,0,0]) cylinder(d=pin_d, h=len); }
module rep_mirror(){ color([0.75,0.87,0.95,0.95]) cube([mirror_w-lip-1, wedge_len, mirror_t]); }
module rep_cam(){
    color("#222222") cube([34,26,34], center=true);
    color("SteelBlue") translate([0,13,0]) rotate([-90,0,0]) cylinder(d=16, h=5);
}

module rep_belt(cd, z){                                 // round belt around both grooves
    rp = platter_od/2 - belt_dia*0.3;  rd = pulley_od/2 - belt_dia*0.3;
    translate([0,0,z-belt_dia/2]) color("DimGray") linear_extrude(belt_dia)
        difference(){
            hull(){ circle(rp+belt_dia/2); translate([cd,0]) circle(rd+belt_dia/2); }
            hull(){ circle(rp-belt_dia/2); translate([cd,0]) circle(rd-belt_dia/2); }
        }
}
// 608 riding platter, round belt from the stepper pulley, dish + LED on top.
module asm_turntable(e=0){
    cd = drive_cd();
    ap = $t*360;                                        // platter angle (Animate)
    color("Tan")            turntable_base();
    translate([0,0,-brg_th - e*14])   rep_bearing();
    translate([cd,0, -e*45])          rep_stepper();
    translate([cd,0, 0.2 + e*34]) rotate([0,0, ap*platter_od/pulley_od])   // drive pulley (same dir)
        color("Orange") drive_pulley();
    translate([0,0, 0.2 + e*34]) rotate([0,0,ap]) color("MediumSeaGreen") platter();
    rep_belt(cd, 0.2 + e*34 + groove_th/2);                                // belt tracks the grooves
    translate([0,0, 12.2 + e*70]) rotate([0,0,ap]) color("DarkRed") led_ring();
    translate([0,0, 15   + e*95]) rotate([0,0,ap]) color([0.8,0.9,1,0.55]) subject_dish();
}

// mirror trays folded to wedge_angle, hinge pin, mirror strips. The gauge is
// a REMOVABLE setting jig (solid -> it plugs the tunnel), so it's shown at the
// far end only and omitted once the yoke holds the angle (gauge=false).
module asm_wedge(e=0, gauge=true){
    hz = back_t/2;
    color("SkyBlue")        translate([0,0,hz]) rotate([0,-wedge_angle/2,0]) translate([0,0,-hz]) mirror_tray(0);
    color("LightSteelBlue") translate([0,0,hz]) rotate([0, wedge_angle/2,0]) translate([0,0,-hz]) mirror_tray(1);
    translate([0, -e*45, hz]) rep_pin(wedge_len+2);                          // hinge pin, pulled out
    translate([0,0,hz]) rotate([0,-wedge_angle/2,0]) translate([1,0,back_t + e*20]) rep_mirror();
    translate([0,0,hz]) rotate([0, wedge_angle/2,0]) translate([1,0,back_t + e*20]) rep_mirror();
    if(gauge) color("Salmon") translate([0, wedge_len-2 + e*45, hz]) rotate([90,0,0]) angle_gauge();
}

// rail_foot securing a vertical rail to the base, with a carriage clamped on it.
// Explode lifts the foot off its bolts and slides the carriage up the rail.
module asm_rail(e=0){
    w=44; rb=(rod_d+fit)/2; zc=8+rb; th=8; len=30;
    color("Tan") translate([0,0,-e*18]) rail_foot();                         // secures rod to base
    color("SteelBlue") translate([0,0,6]) cylinder(d=rod_d, h=150);          // vertical rail
    translate([0,0, 72 + e*40])                                              // carriage clamped on rail
        translate([-zc, -w/2, -len/2]) rotate([0,0,90]) rotate([90,0,0])
        carriage(len=len, w=w, top_th=th);
}

// whole instrument on a chassis board: enclosure + drive, two rails on feet,
// a bridge across the rails carrying the chosen head (wedge or tri) + camera.
module asm_full(){
    a=wedge_angle/2; hz=back_t/2; acx=2*mirror_w*cos(a)/3;
    bz = 40 + wedge_len;                                                      // bridge height
    fa = [180-rail_span_ang/2, 180+rail_span_ang/2];
    color("BurlyWood") rep_board();                                          // chassis board (user-supplied)
    color([0.55,0.68,0.85,0.85]) enclosure();                               // electronics box
    asm_turntable(0);                                                        // drive on top
    for(ang=fa) translate([rail_foot_r*cos(ang), rail_foot_r*sin(ang), board_z()]){
        color("Tan") rotate([0,0,ang]) rail_foot();                         // rail secured to board
        translate([0,0,2]) rep_rod_v(bz - board_z() + 42);
    }
    translate([0,0,bz]) color("Plum") rail_bridge();                         // bridge clamps both rails
    if(head=="tri") translate([0,0,bz]) tri_head_hung();                     // 3-mirror head
    else translate([0,0,bz]) rotate([-90,0,0]) translate([-acx,0,-hz]){      // 2-mirror wedge + yoke
        asm_wedge(0, gauge=false);
        color("Orchid") wedge_yoke();
    }
    translate([0,0,bz+22]) rep_cam();                                        // camera looking down
}

// drive base sitting on its enclosure, stepper hanging inside - checks the fit
module asm_enclosure(e=0){
    cd = drive_cd();
    color([0.55,0.68,0.85,0.9]) translate([0,0,-e*40]) enclosure();
    color("Tan")     turntable_base();
    translate([cd,0,0]) rep_stepper();
}

// --------------------------------------------------------------------------
//  dispatcher
// --------------------------------------------------------------------------
if      (part=="carriage")       carriage();
else if (part=="mirror_tray_a")  mirror_tray(0);
else if (part=="mirror_tray_b")  mirror_tray(1);
else if (part=="angle_gauge")    angle_gauge();
else if (part=="wedge_yoke")     wedge_yoke();                   // cradles wedge -> bridge
else if (part=="wedge_asm")      wedge_asm();
else if (part=="tri_bracket")    tri_bracket(false);             // 3-mirror bracket (print 1-2)
else if (part=="tri_bracket_top")tri_bracket(true);             // 3-mirror top bracket -> bridge
else if (part=="tri_head")       tri_head();                     // 3-mirror head preview
else if (part=="camera_mount")   camera_mount();
else if (part=="turntable_base") turntable_base();
else if (part=="rail_foot")      rail_foot();                    // bolt-on rail foot
else if (part=="rail_bridge")    rail_bridge();                  // clamps both rails, holds wedge/camera
else if (part=="platter")        platter();
else if (part=="drive_pulley")   drive_pulley();                 // stepper belt pulley
else if (part=="subject_dish")   subject_dish();
else if (part=="led_ring")       led_ring();
else if (part=="enclosure")      enclosure();                    // electronics box under the base
else if (part=="asm_enclosure")  asm_enclosure(explode);         // base + stepper + box fit check
else if (part=="asm_turntable")  asm_turntable(explode);
else if (part=="asm_wedge")      asm_wedge(explode);
else if (part=="asm_rail")       asm_rail(explode);
else if (part=="asm_full")       asm_full();
else {                                   // "all" - scatter for a look
    carriage();
    translate([-95,  0,0]) wedge_asm();
    translate([ 85,  0,0]) camera_mount();
    translate([  0,200,0]) turntable_base();
    translate([250,200,0]) platter();
    translate([ 84,200,0]) drive_pulley();
    translate([250, 70,0]) subject_dish();
    translate([130, 70,0]) led_ring();
    translate([-95,160,0]){ mirror_tray(0); translate([0,0,22]) mirror_tray(1); translate([60,0,0]) angle_gauge(); }
}

// ==========================================================================
//  ASSEMBLY NOTES
//  - Rail: cut two smooth rods to length, drop carriages on, tighten the
//    clamp screw. Bolt the wedge / camera / turntable to a carriage top grid.
//  - Chassis: mount the enclosure and two `rail_foot`s to a shared board
//    (plywood/acrylic). Each foot bolts down (2x M3) and clamps a rod with
//    its pinch bolt. Rails sit at rail_foot_r on the far side from the stepper
//    so they clear the spinning platter; widen rail_span_ang / rail_foot_r
//    to suit. This replaces the old integral-rail base.
//  - Three-mirror head (alt to the wedge): cut three mirror strips
//    (mirror_w x wedge_len), glue one to each inner face of two `tri_bracket`s
//    (top = tri_bracket_top for the bridge grid); set head="tri" to preview.
//  - Mirror wedge: print mirror_tray_a + mirror_tray_b, glue a front-surface
//    mirror strip into each channel (reflective side to the interior),
//    interleave the knuckles, slide a 120 mm x 3 mm rod down the vertex.
//    Drop an angle_gauge (regenerate with a new `wedge_angle`) at one end to
//    set 4/6/8/10/12-fold symmetry; a rubber band holds the mirrors on it.
//  - Camera at the vertex looking down the tunnel; subject stage at the far
//    end. USB webcam via zip-ties, or a tripod-thread cam on the 1/4"-20.
//  - Wedge yoke: print `wedge_yoke`, slide the two mirror trays' outer edges
//    up into its grips and nip the set screws. Bolt the yoke's flange to the
//    rail bridge (its holes match the bridge's M3 grid, aperture over the
//    optical bore). The wedge now hangs from the bridge with the tunnel over
//    the dish and the camera looking straight down it. Reprint the yoke if
//    you change wedge_angle (grips are cut at +-wedge_angle/2).
//  - Turntable (round-belt drive): press a 608 into the base boss, press the
//    platter hub into the bearing, bolt a NEMA-11 under the bracket, set-screw
//    the drive_pulley on its shaft. Loop a round rubber belt (belt_dia) around
//    the pulley + platter grooves - size it a touch short so it self-tensions
//    (no idler needed). Reduction ~ platter_od/pulley_od. Keep oil off the
//    belt/grooves (it's a friction drive). Drive from your XIAO LFO/CV source.
//  - Backlight: seat a WS2812 ring in led_ring behind the dish; drive from
//    the same firmware to colour-cycle / strobe in sync.
//
//  TUNING: everything is parametric up top. `rod_d` for your rail stock,
//  `wedge_angle` for symmetry, `platter_od`/`pulley_od` for platter size &
//  belt reduction, `dish_od` for your stage. For a native-analog path, swap
//  the webcam for a CCD module on the same camera carriage.
// ==========================================================================

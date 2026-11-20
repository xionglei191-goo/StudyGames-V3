"""Build full-size, tintable workbench models. Run with Blender --background --python."""
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts/layer2_blender"))
from primitives import (MATERIALS, botanical_leaf, collect_and_export, curve_tube, ellipsoid, init_materials,
                        lathe, rbox, rcone, rcyl, rtorus, star_mesh)
from surface_finishes import finish_blend_materials

SOURCE = ROOT / "assets/art/handcrafted_furniture"
RUNTIME = ROOT / "game/assets/props/handcrafted_furniture"


def spindle(name, foot, top, r0, r1, material="wood"):
    a, b = Vector(foot), Vector(top)
    obj = rcone(name, tuple((a+b)/2), r0, r1, (b-a).length, material, verts=18)
    obj.rotation_euler = (b-a).to_track_quat("Z","Y").to_euler()


def joinery(stool, square):
    w = 0.8 if stool else 1.55
    # The printable surface is at 0.98 m on every table, including saved designs.
    h = 0.55 if stool else (0.912 if square else 0.902)
    if square:
        rbox("Timber_painted_top",(0,0,h),(w,w,0.13),"tint",bevel=0.041,segs=5)
        rbox("Timber_lower_lip",(0,0,h-0.056),(w-0.046,w-0.046,0.043),"wood",bevel=0.018)
    else:
        lathe("Timber_turned_seat",[(0,h-0.078),(w*0.44,h-0.077),(w*0.465,h-0.058),
            (w*0.495,h-0.045),(w/2,h+0.015),(w*0.494,h+0.058),(w*0.477,h+0.074),(0,h+0.075)],
            "tint",steps=64,subsurf=0)
        rtorus("Timber_seat_bead",(0,0,h-0.049),w*0.482,0.009,"wood")
    foot, shoulder = w*0.306, w*(0.271 if square else 0.242)
    for sx in (-1,1):
        for sy in (-1,1):
            spindle("Timber_tapered_leg",(sx*foot,sy*foot,0.008),(sx*shoulder,sy*shoulder,h-0.063),
                    0.031 if stool else 0.043,0.051 if stool else 0.063)
            # Cabinetmaker's pegs show where the legs meet the seat.
            if stool:
                rcyl("Timber_endgrain_peg",(sx*shoulder,sy*shoulder,h+(0.075 if not square else 0.065)),0.018,0.002,"wood_dark",verts=18)
        for z,axis in ((h*0.31,0),(h*0.37,1)):
            dist = foot + (shoulder-foot)*z/h
            a,b = (-dist,sx*dist,z),(dist,sx*dist,z)
            if axis:
                a,b = (a[1],a[0],z),(b[1],b[0],z)
            spindle("Timber_stretcher",a,b,0.019 if stool else 0.027,0.019 if stool else 0.027)


def frame(sign):
    for x in (-0.43,0.43):
        rbox("Timber_foot",(x,0,0.038),(0.18,0.53,0.076),"wood_dark",bevel=0.023)
        spindle("Timber_upright",(x,0.08,0.066),(x,0.035,1.63),0.045,0.039)
        spindle("Timber_easel_brace",(x,0.23,0.075),(x,0.06,0.85),0.024,0.026)
    rbox("Timber_panel",(0,0,1.25),(1.45,0.116,1.08),"wood",bevel=0.032)
    for x in (-0.678,0.678):
        rbox("Timber_painted_stile",(x,-0.056,1.25),(0.096,0.067,1.08),"tint",bevel=0.014)
    for z in (0.747,1.753):
        rbox("Timber_painted_rail",(0,-0.056,z),(1.27,0.067,0.073),"tint",bevel=0.012)
    if sign:
        for x in (-0.677,0.677):
            for z in (0.748,1.752):
                rcyl("Flush_pin",(x,-0.089,z),0.014,0.005,"gold",verts=12,rot=(90,0,0))
    else:
        for x in (-0.636,0.636):
            rbox("Frame_inner_bead",(x,-0.082,1.25),(0.016,0.016,0.92),"gold",bevel=0.005)


def display_stand():
    joinery(False,True)
    for i in range(5):
        rbox("Timber_lower_slat",(0,i*.215-.43,.288),(1.12,.19,.050),"wood",bevel=.012)
    for side in (-1,1):
        rbox("Timber_scalloped_apron",(side*.44,0,.776),(.073,.98,.12),"tint_dark",bevel=.025)


def rug():
    rbox("Linen_hemmed_rug",(0,0,0.017),(1.95,1.5,0.031),"tint",bevel=0.012)
    for side in (-1,1):
        for k in range(24):
            y = -0.69 + k*0.060
            curve_tube("Linen_fringe",[(side*0.965,y,0.020),(side*0.995,y+0.004,0.016),
                (side*(1.032+0.006*math.sin(k*2.2)),y+0.010*math.sin(k),0.008)],
                0.006,"cream",bevel_res=1)
        rbox("Linen_bound_edge",(side*0.928,0,0.033),(0.030,1.48,0.006),"tint_dark",bevel=0.002)


def flower_vase(tall):
    w, h = (0.21,0.56) if tall else (0.255,0.46)
    lathe("Glazed_stoneware",[(0,0),(w*.58,0),(w*.64,.025),(w*.66,.054),(w*.97,h*.35),
          (w,h*.58),(w*.88,h*.74),(w*.43,h*.86),(w*.41,h*.95),(w*.49,h*.98),(w*.48,h),
          (w*.34,h),(w*.34,h*.93),(w*.45,h*.81),(w*.64,h*.60),(0,.10)],"tint",steps=48)
    rtorus("Glazed_rim",(0,0,h-0.007),w*0.43,0.012,"cream")
    for i in range(5):
        a = 2.40*i
        x,y = math.cos(a)*(0.21 if i else 0.015), math.sin(a)*0.145
        z = h+0.37+0.11*math.cos(a+0.4)
        curve_tube("Flower_stem",[(0,0,h*.68),(x*.18,y*.24,h+.04),(x*.74,y*.8,z-.10),(x,y,z)],0.011,"leaf",bevel_res=2)
        botanical_leaf("Flower_leaf",(x*.45,y*.45,h+0.10),(x+0.10*math.cos(a),y+.12*math.sin(a),z-.10),
                       0.04,0.02,"leaf","leaf_light")
        for k in range(7):
            b = k*math.tau/7+a
            ellipsoid("Petal",(x+.048*math.cos(b),y+.048*math.sin(b),z+.012),
                      (.061,.032,.021),"cream" if i%2 else "pink",segs=16,rings=8,rot=(0,-13,math.degrees(b)))
        ellipsoid("Pollen",(x,y,z+.027),(.035,.035,.025),"yellow",segs=16,rings=8)


def basket():
    lathe("Basket_inner",[(0,.012),(.23,.012),(.27,.06),(.348,.34),(.336,.35),(.25,.072),(0,.052)],"tint_dark",steps=48)
    for j in range(10):
        z = 0.047+j*0.033
        r = 0.257+0.091*z/0.35
        pts = []
        for i in range(96):
            a = i*math.tau/96
            radius = r+0.008*math.cos(16*a+j*math.pi)
            pts.append((radius*math.cos(a),radius*math.sin(a),z))
        curve_tube("Basket_woven_row",pts,0.016,"tint" if j%3 else "wood",closed=True,bevel_res=2,smooth_spline=False)
    for i in range(32):
        a = i*math.tau/32
        spindle("Basket_stake",(.252*math.cos(a),.252*math.sin(a),.034),
                (.345*math.cos(a),.345*math.sin(a),.36),.011,.011,"wood")
    rtorus("Basket_bound_rim",(0,0,0.36),0.349,0.023,"wood",major_seg=56,minor_seg=10)
    pts = [(.345*math.cos(i*math.pi/24),0,.36+.295*math.sin(i*math.pi/24)) for i in range(25)]
    curve_tube("Basket_handle",pts,.024,"wood_dark",bevel_res=3)


def lantern():
    lathe("Timber_lamp_foot",[(0,0),(.29,0),(.33,.033),(.32,.079),(.22,.105),(.085,.133),(0,.136)],"wood",subsurf=0)
    lathe("Lamp_stem",[(0,.1),(.063,.1),(.049,.20),(.044,.91),(.069,.96),(0,.97)],"wood_dark",steps=24)
    profile = [(0,.94),(.13,.94),(.225,1.01),(.30,1.16),(.325,1.28),(.30,1.40),(.22,1.53),(.13,1.58),(0,1.58)]
    lathe("Linen_paper_lantern",profile,"tint_light",steps=56)
    for r,z in ((.134,.953),(.301,1.16),(.325,1.28),(.301,1.40),(.134,1.57)):
        rtorus("Lantern_hoop",(0,0,z),r,.008,"wood",major_seg=48,minor_seg=8)
    for i in range(8):
        a = i*math.tau/8
        curve_tube("Bamboo_rib",[(r*math.cos(a),r*math.sin(a),z) for r,z in profile[1:-1]],.007,"wood",bevel_res=1)
    star_mesh("Lantern_star",(0,-.322,1.28),.066,.031,.012,mat="gold",rot=(90,0,0))
    rtorus("Lamp_handle",(0,0,1.626),.054,.007,"gold",rot=(90,0,0))


def shelf():
    for x in (-.51,.51):
        rbox("Timber_side",(x,0,.65),(.073,.54,1.30),"tint",bevel=.020)
    rbox("Timber_back",(0,.235,.65),(1.04,.056,1.26),"tint_light",bevel=.014)
    for row,z in enumerate((.09,.65,1.24)):
        rbox("Timber_shelf",(0,-.01,z),(1.10,.55,.074),"wood",bevel=.015)
        if row == 2:
            continue
        x = -.439
        for k,color in enumerate(("leaf","berry","cream","sky","orange","tint_dark")):
            w,h = .061+.013*((k+row)%3), .284+.049*((k+2*row)%4)
            yaw = -11 if k == 5 else 0
            x += w*.55
            rbox("Book_pages",(x,-.025,z+.041+h/2),(w,.289,h),"paper",bevel=.005,rot=(0,yaw,0))
            rbox("Book_spine",(x,-.17,z+.041+h/2),(w+.006,.025,h+.009),color,bevel=.009,rot=(0,yaw,0))
            for frac in (.17,.80):
                rbox("Gilt_spine_band",(x+(frac-.5)*h*math.sin(math.radians(yaw)),-.185,z+.041+h*frac),
                     (w*.78,.004,.007),"gold",bevel=.001)
            x += w*.65


def apple_wedge(center, angle, skin):
    # Rest one cut face on the plate. The curved peel and two pale cut faces
    # meet along shared edges, so the skin stays thin when viewed up close.
    points, faces, peel_faces = [], [], []
    steps, arc = 16, 8
    width = arc+2
    for i in range(steps+1):
        t = 2*i/steps-1
        radius = 0.082*math.sqrt(max(0.001,1-t*t))*(1+0.08*t)
        x = 0.111*t
        points.append((x,0,0))
        for j in range(arc+1):
            phi = 1.15*j/arc
            points.append((x,radius*math.cos(phi),radius*math.sin(phi)))
        if i:
            for j in range(width):
                a = (i-1)*width+j
                b = (i-1)*width+(j+1)%width
                if 0 < j <= arc:
                    peel_faces.append(len(faces))
                faces.append((a,b,b+width,a+width))
    faces.extend([tuple(reversed(range(width))),tuple(range(len(points)-width,len(points)))])
    mesh = bpy.data.meshes.new("Apple_wedge")
    mesh.from_pydata(points,[],faces)
    mesh.update()
    obj = bpy.data.objects.new("Apple_slice",mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = center
    obj.rotation_euler.z = angle
    mesh.materials.append(MATERIALS["apple_flesh"])
    mesh.materials.append(MATERIALS[skin])
    for index in peel_faces:
        face = mesh.polygons[index]
        face.material_index = 1
        face.use_smooth = True


def apple_plate(cake):
    lathe("Glazed_plate",[(0,0),(.25,0),(.28,.014),(.45,.033),(.48,.058),(.47,.073),(.41,.059),(.30,.039),(0,.038)],
          "cream",steps=52)
    rtorus("Glazed_handpainted_edge",(0,0,.061),.454,.008,"tint")
    if cake:
        lathe("Cake_crumb",[(0,.041),(.30,.041),(.335,.063),(.338,.262),(.321,.29),(0,.29)],"bread",steps=44)
        rcyl("Jam_layer",(0,0,.166),.339,.014,"berry",verts=48)
        rcyl("Buttercream",(0,0,.181),.340,.016,"cream",verts=48)
        lathe("Icing",[(0,.265),(.325,.265),(.344,.275),(.339,.291),(.297,.308),(0,.308)],"cream",steps=48)
    z = .307 if cake else .040
    for i in range(5):
        a = i*math.tau/5+.12
        apple_wedge((.189*math.cos(a),.189*math.sin(a),z),a-math.pi/2+.18,"tint" if i%2 else "berry")
    botanical_leaf("Mint",(0,0,z+.002),(.081,-.031,z+.031),.029)
    botanical_leaf("Mint",(0,0,z+.002),(-.062,.054,z+.029),.029)


def main():
    for directory in (SOURCE, RUNTIME):
        directory.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    init_materials()
    builders = {
        "stool_round": lambda: joinery(True,False), "stool_square": lambda: joinery(True,True),
        "table_round": lambda: joinery(False,False), "table_square": lambda: joinery(False,True),
        "stand": display_stand, "sign": lambda: frame(True), "frame": lambda: frame(False),
        "rug": rug, "basket": basket, "lantern": lantern, "shelf": shelf,
        "vase_round": lambda: flower_vase(False), "vase_tall": lambda: flower_vase(True),
        "cake": lambda: apple_plate(True), "plate": lambda: apple_plate(False),
    }
    records, objects = [], []
    for key, builder in builders.items():
        obj, record = collect_and_export(key, builder, None, SOURCE, RUNTIME)
        objects.append(obj)
        records.append(record)
    for i,obj in enumerate(objects):
        obj.location = (2.5*(i%5),2.15*(i//5),0)
    finish_blend_materials(ROOT)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/"handcrafted_furniture.blend"))
    (SOURCE/"manifest.json").write_text(json.dumps({"authoring":"Original parametric Blender models in metres.",
        "source":"scripts/build_craft_models.py","assets":records},indent=2),encoding="utf8")


if __name__ == "__main__":
    main()

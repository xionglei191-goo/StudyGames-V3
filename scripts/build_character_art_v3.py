"""Author the island's twelve skinned storybook characters in Blender.

Run with Blender --background --factory-startup --python this_file.py.
The editable .blend and glTF skins are retained. A geometry-only JSON interchange
is also emitted for Godot's existing P1 skeleton, preserving its contact timings.
No existing source model, gameplay marker, animation or save file is overwritten.
"""
from __future__ import annotations

import bpy
import bmesh
import json
import math
import hashlib
from pathlib import Path
from mathutils import Vector, Matrix
from collections import defaultdict

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/characters/storybook_v3"
DATA = OUT / "source"
OUT.mkdir(parents=True, exist_ok=True)
DATA.mkdir(parents=True, exist_ok=True)

PROFILES = {
    "player": dict(name="小岛旅人", hair="674737", outfit="e6b946", trim="f4ead4", style="bob", overalls=True, backpack=True),
    "npc_bear_uncle": dict(name="熊叔", kind="bear", outfit="78a8b6", trim="eee0bc"),
    "npc_rabbit_gardener": dict(name="兔兔", kind="rabbit", outfit="86a57a", trim="ebdbb2"),
    "textbook_lingling": dict(name="Lingling", hair="242729", outfit="dc8ea5", trim="f5dbe0", style="pigtails", dress=True),
    "textbook_peter": dict(name="Peter", hair="dfb758", outfit="f1e8cf", trim="dca04c", style="curls", shorts="dca04c"),
    "textbook_anne": dict(name="Anne", hair="bd6943", outfit="8fbbcb", trim="a39eb7", style="ponytail", dress=True),
    "textbook_mingming": dict(name="Mingming", hair="2e3032", outfit="7198b5", trim="d8e1dc", style="short", shorts="587f9f"),
    "textbook_dongdong": dict(name="Dongdong", hair="2b2e30", outfit="e2bd56", trim="f4e6c8", style="short", shorts="c57668", striped=True),
    "textbook_tim": dict(name="Tim", hair="a86a47", outfit="f0e8d4", trim="6ca4a0", style="curls", shorts="6ca4a0"),
    "textbook_dino": dict(name="Dino", kind="dino", outfit="86ac75", trim="e4d9b4"),
    "textbook_miss_li": dict(name="Miss Li", hair="292a2e", outfit="d49cae", trim="ead3d8", style="bob", dress=True),
    "textbook_jim": dict(name="Jim", hair="8b6247", outfit="dadbd1", trim="7d99a1", style="short", kind="wheelchair"),
}
G2B = Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
B2G = G2B.inverted()


def color(hexcode):
    return tuple(int(hexcode[i:i+2],16)/255 for i in (0,2,4))+(1.0,)


def linear(c):
    return tuple(x/12.92 if x <= .04045 else ((x+.055)/1.055)**2.4 for x in c[:3])+(1.0,)


def bone_layout(kind, seated=False):
    hips = .88 if seated else .79
    bones = [("Hips",None,(0,hips,0),(0,0,0)),("Spine","Hips",(0,.2,0),(0,0,0)),("Head","Spine",(0,.56,0),(0,0,0))]
    for side, sign in (("L",-1),("R",1)):
        bones.extend([(f"UpperArm_{side}","Spine",(sign*.39,.22,0),(0,0,0)),
                      (f"LowerArm_{side}",f"UpperArm_{side}",(0,-.34,0),(0,0,0)),
                      (f"UpperLeg_{side}","Hips",(sign*.18,-.03,0),(-math.pi/2,0,0) if seated else (0,0,0)),
                      (f"LowerLeg_{side}",f"UpperLeg_{side}",(0,-.38,0),(math.pi/2,0,0) if seated else (0,0,0))])
    if kind == "dino":
        bones.extend([("Tail","Hips",(0,.04,-.22),(0,0,0)),("Wing_L","Spine",(-.25,.2,-.17),(0,0,0)),("Wing_R","Spine",(.25,.2,-.17),(0,0,0))])
    rest={}
    for name,parent,origin,rotation in bones:
        local=Matrix.Translation(Vector(origin)) @ Matrix.Rotation(rotation[0],4,'X')
        rest[name]=rest[parent] @ local if parent else local
    return bones,rest


class Author:
    def __init__(self, id, profile):
        self.id=id; self.p=profile; self.kind=profile.get("kind","human")
        self.bones,self.rest=bone_layout(self.kind,self.kind=="wheelchair")
        _,self.reference=bone_layout(self.kind,False)
        self.parts={}
        self.objects=[]
        self.metrics={}

    def part(self,group):
        if group not in self.parts:
            self.parts[group]=dict(v=[],f=[],w=[],c=[],uv=[],blink=[],smile=[],talk=[])
        return self.parts[group]

    def vertex(self,group,p,w,c,uv=(0,0),blink=None):
        d=self.part(group)
        p=Vector(p); final=Vector((0,0,0))
        blink=Vector(blink) if blink is not None else p.copy()
        final_blink=Vector((0,0,0))
        for bone,weight in w.items():
            deform=self.rest[bone] @ self.reference[bone].inverted()
            final+=(deform @ p)*weight
            final_blink+=(deform @ blink)*weight
        d['v'].append(tuple(G2B @ final)); d['w'].append(w)
        d['blink'].append(tuple(G2B @ final_blink)); d['uv'].append(uv)
        d['smile'].append(tuple(G2B @ final));d['talk'].append(tuple(G2B @ final))
        # Small pigment variation: material colour, not baked scene illumination.
        grain=1+.016*math.sin(p.x*113+p.y*61+p.z*97)
        cc=color(c) if isinstance(c,str) else c
        d['c'].append(tuple(min(1,max(0,x*grain)) for x in cc[:3])+(1,))
        return len(d['v'])-1

    def ellipsoid(self,group,center,radii,c,bone="Head",segments=24,rings=12,blink=False,shape=None):
        d=self.part(group); center=Vector(center)
        def point(theta,phi):
            a=Vector((math.sin(theta)*math.cos(phi),math.cos(theta),math.sin(theta)*math.sin(phi)))
            if shape: a=shape(a)
            return center+Vector(tuple(a[i]*radii[i] for i in range(3)))
        ids=[]
        for j in range(1,rings):
            row=[]
            for i in range(segments):
                p=point(math.pi*j/rings,2*math.pi*i/segments)
                closed=p.copy()
                if blink: closed.y=center.y+(p.y-center.y)*.055
                row.append(self.vertex(group,p,{bone:1},c,(i/segments,j/rings),closed))
            ids.append(row)
        top=self.vertex(group,point(0,0),{bone:1},c,(.5,0),center+Vector((0,radii[1]*.055,0)) if blink else None)
        bottom=self.vertex(group,point(math.pi,0),{bone:1},c,(.5,1),center-Vector((0,radii[1]*.055,0)) if blink else None)
        for i in range(segments):
            n=(i+1)%segments
            d['f'].append((top,ids[0][i],ids[0][n]))
            d['f'].append((bottom,ids[-1][n],ids[-1][i]))
        for j in range(len(ids)-1):
            for i in range(segments):
                n=(i+1)%segments
                d['f'].append((ids[j][i],ids[j+1][i],ids[j+1][n],ids[j][n]))

    def loft(self,group,rings,c,weights,segments=24,ruffle=0):
        # Rings: center xyz, radius x and z. Closed, quad-dominant deformation loops.
        d=self.part(group); ids=[]
        for j,(x,y,z,rx,rz) in enumerate(rings):
            row=[]
            for i in range(segments):
                phi=math.tau*i/segments
                detail=1+ruffle*math.cos(8*phi)*max(0,1-j/max(1,len(rings)-1))
                p=(x+rx*math.cos(phi)*detail,y,z+rz*math.sin(phi)*detail)
                w=weights(j/(len(rings)-1),p) if callable(weights) else {weights:1}
                row.append(self.vertex(group,p,w,c,(i/segments,j/(len(rings)-1))))
            ids.append(row)
        for j in range(len(ids)-1):
            for i in range(segments):
                n=(i+1)%segments
                d['f'].append((ids[j][i],ids[j][n],ids[j+1][n],ids[j+1][i]))
        for end,reverse in ((0,False),(-1,True)):
            x,y,z,_,_=rings[end]
            w=weights(0 if end==0 else 1,(x,y,z)) if callable(weights) else {weights:1}
            v=self.vertex(group,(x,y,z),w,c,(.5,.5))
            for i in range(segments):
                n=(i+1)%segments
                d['f'].append((v,ids[end][n],ids[end][i]) if reverse else (v,ids[end][i],ids[end][n]))

    def tube(self,group,points,radius,c,bone,segments=8):
        d=self.part(group); rows=[]
        for j,point in enumerate(points):
            p=Vector(point)
            direction=Vector(points[min(j+1,len(points)-1)])-Vector(points[max(0,j-1)])
            tangent=direction.normalized()
            axis=tangent.cross(Vector((0,0,1)))
            if axis.length < .001: axis=tangent.cross(Vector((0,1,0)))
            axis.normalize(); other=tangent.cross(axis).normalized()
            rows.append([self.vertex(group,p+radius*(axis*math.cos(math.tau*i/segments)+other*math.sin(math.tau*i/segments)),{bone:1},c,(i/segments,j/max(1,len(points)-1))) for i in range(segments)])
        for j in range(len(rows)-1):
            for i in range(segments):
                n=(i+1)%segments
                d['f'].append((rows[j][i],rows[j][n],rows[j+1][n],rows[j+1][i]))
        d['f'].append(tuple(reversed(rows[0])));d['f'].append(tuple(rows[-1]))

    def ring(self,group,center,rx,ry,c,bone,radius=.008,plane="xy",segments=48):
        x,y,z=center
        if plane=="xy": pts=[(x+rx*math.cos(math.tau*i/segments),y+ry*math.sin(math.tau*i/segments),z) for i in range(segments+1)]
        elif plane=="yz": pts=[(x,y+rx*math.cos(math.tau*i/segments),z+ry*math.sin(math.tau*i/segments)) for i in range(segments+1)]
        else: pts=[(x+rx*math.cos(math.tau*i/segments),y,z+ry*math.sin(math.tau*i/segments)) for i in range(segments+1)]
        self.tube(group,pts,radius,c,bone)

    def seam(self,group,points,c,bone,radius=.006):
        self.tube(group,points,radius,c,bone,6)

    def face(self,animal=False,dino=False):
        y=1.55
        def surface(x,yy):
            # Features follow the head/muzzle surface, never hover in front of it.
            rx,ry,rz,cy=(.47,.42,.39,1.57) if dino else (.465,.42,.38,1.55) if animal else (.405,.395,.344,1.55)
            z=rz*math.sqrt(max(0,1-(x/rx)**2-((yy-cy)/ry)**2))
            if dino or (animal and self.kind=='bear'):
                mx,my,mz,mcy,mcz=(.35,.185,.22,1.42,.34) if dino else (.22,.147,.10,1.406,.35)
                term=1-(x/mx)**2-((yy-mcy)/my)**2
                if term>0:z=max(z,mcz+mz*math.sqrt(term))
            return z
        eye_x=.153 if not dino else .213
        for sign in (-1,1):
            x=sign*eye_x
            z=surface(x,y+.015)+.012
            self.ellipsoid("Eyes",(x,y+.015,z),(.047,.062,.029),"3b352e",blink=True,segments=20)
            self.ellipsoid("Eyes",(x-.014,y+.038,z+.024),(.014,.016,.009),"fff9e9",blink=True,segments=12,rings=8)
            self.ellipsoid("Face",(sign*.255,y-.105,surface(sign*.255,y-.105)+.001),(.060,.028,.010),"d99f8b",segments=20)
            # Eyebrows are short arcs that read at game scale.
            self.seam("Hair",[(xx,yy,surface(xx,yy)+.006) for xx,yy in ((x-.047,y+.109),(x,y+.123),(x+.047,y+.112))],"654b3b" if animal or dino else self.p['hair'],"Head",.009)
        if not dino:self.ellipsoid("Face",(0,y-.072,surface(0,y-.072)+.015),(.037,.035,.04),"72503d" if animal else "dfaa8f",segments=16,rings=10)
        # A shallow smile arc, not a floating line through the face.
        start=len(self.part('Face')['v'])
        self.seam("Face",[(xx,yy,surface(xx,yy)+.007) for xx,yy in ((-.065,y-.158),(-.037,y-.177),(0,y-.182),(.037,y-.177),(.065,y-.158))],"8f6150","Head",.008)
        face=self.part('Face')
        deform=self.rest['Head'] @ self.reference['Head'].inverted()
        for index in range(start,len(face['v'])):
            old=deform.inverted() @ (B2G @ Vector(face['v'][index]))
            x=old.x*1.24;yy=old.y-.012*max(0,1-abs(old.x)/.08)
            zz=surface(x,yy)+(old.z-surface(old.x,old.y))
            face['smile'][index]=tuple(G2B @ (deform @ Vector((x,yy,zz))))
        # A hidden closed mouth volume becomes a small opening while talking.
        # It is below the face at rest and does not add a second painted smile.
        start=len(face['v']);my=y-.17
        self.ellipsoid('Face',(0,my,surface(0,my)-.012),(.047,.004,.006),'704a3c','Head',20,10)
        for index in range(start,len(face['v'])):
            old=deform.inverted() @ (B2G @ Vector(face['v'][index]))
            yy=my+(old.y-my)*7.5
            zz=surface(old.x,yy)+.013+(old.z-(surface(0,my)-.012))
            face['talk'][index]=tuple(G2B @ (deform @ Vector((old.x,yy,zz))))

    def limbs(self,skin,shirt,trim):
        shorts='ffffff' if self.id=='player' else self.p.get('shorts',self.p['outfit'])
        animal=self.kind in ('bear','rabbit')
        thickness=1.19 if animal else 1.0
        for side,sign in (("L",-1),("R",1)):
            upper=f"UpperArm_{side}";lower=f"LowerArm_{side}"
            def arm_weights(t,p,u=upper,l=lower):
                f=max(0,min(1,(.94-p[1])/.15)); f=f*f*(3-2*f)
                return {u:1-f,l:f}
            rings=[]
            for j in range(17):
                t=j/16; y=1.24-.69*t
                rad=(.079+.021*math.sin(math.pi*t)-.008*t)*thickness
                if j==0:rad=.065
                if j==16:rad=.066
                rings.append((sign*(.39+.035*math.sin(math.pi*t)),y,.006,rad,rad*.96))
            self.loft("Body",rings,skin,arm_weights,20)
            self.loft("Details" if self.id=='player' else "Outfit",[(sign*.39,1.23,0,.095,.1),(sign*.402,1.19,0,.12,.119),(sign*.414,1.12,0,.121,.115),(sign*.417,1.055,0,.107,.104)],trim if self.id=='player' else shirt,upper,20)
            self.ring("Details",(sign*.417,1.057,0),.109,.106,trim,upper,.009,"xz",24)
            self.ellipsoid("Body",(sign*.40,.555,.035),(.095*thickness,.107,.081*thickness),skin,lower,20,12)
            self.ellipsoid("Body",(sign*.332,.578,.091),(.043,.06,.047),skin,lower,16,10)
            for finger in range(3):
                x=sign*(.362+.027* finger)
                self.seam("Details",[(x,.52,.096),(x,.55,.112),(x,.576,.111)],"c7997f" if self.kind=='human' else skin,lower,.0035)
            thigh=f"UpperLeg_{side}";shin=f"LowerLeg_{side}"
            def leg_weights(t,p,u=thigh,l=shin):
                f=max(0,min(1,(.46-p[1])/.16));f=f*f*(3-2*f)
                return {u:1-f,l:f}
            leg_rings=[(sign*.18,.77-.65*j/16,0,(.107-.027*j/16)*thickness,(.103-.026*j/16)*thickness) for j in range(17)]
            self.loft("Body",leg_rings,skin,leg_weights,20)
            if not self.p.get('dress',False):
                if animal:
                    self.loft("Outfit",[(sign*.18,.78,0,.15,.14),(sign*.18,.66,0,.16,.15),(sign*.18,.52,0,.15,.14),(sign*.18,.38,0,.14,.13),(sign*.18,.27,0,.125,.12)],shorts,leg_weights,24)
                    self.ring("Details",(sign*.18,.28,0),.129,.124,trim,shin,.010,"xz",24)
                else:
                    self.loft("Outfit",[(sign*.18,.78,0,.139,.127),(sign*.18,.68,0,.14,.132),(sign*.18,.57,0,.134,.125),(sign*.18,.51,0,.123,.119)],shorts,thigh,20)
                    self.ring("Details",(sign*.18,.515,0),.126,.12,trim,thigh,.009,"xz",24)
            self.loft("Details",[(sign*.18,.245,0,.086,.085),(sign*.18,.195,0,.087,.086),(sign*.18,.13,.007,.085,.087)],"f4ead4",shin,20)
            self.ellipsoid("Shoes",(sign*.18,.095,.075),(.136,.105,.221),trim,shin,24,12)
            self.ellipsoid("Details",(sign*.18,.047,.08),(.137,.035,.218),"e8dcc3",shin,24,10)
            for j in range(3):
                yy=.172-j*.006;zz=.11+j*.036
                self.seam("Details",[(sign*.18-.057,yy,zz),(sign*.18+.057,yy,zz)],"faf2dd",shin,.007)

    def hair(self):
        c=self.p['hair'];style=self.p['style']
        # A shaped cap with a scalloped hairline and tapered locks; no bead row.
        d=self.part('Hair');rows=[];n=40
        for j in range(15):
            t=j/14; row=[]
            for i in range(n):
                phi=math.tau*i/n
                front=max(0,math.sin(phi));back=max(0,-math.sin(phi))
                end=1.30+.57*back+.09*math.cos(phi*5)*front
                theta=.045+t*end
                p=(.425*math.sin(theta)*math.cos(phi),1.55+.417*math.cos(theta),-.015+.359*math.sin(theta)*math.sin(phi))
                row.append(self.vertex('Hair',p,{'Head':1},c,(i/n,t)))
            rows.append(row)
        for j in range(len(rows)-1):
            for i in range(n):
                k=(i+1)%n;d['f'].append((rows[j][i],rows[j+1][i],rows[j+1][k],rows[j][k]))
        d['f'].append(tuple(reversed(rows[0])))
        d['f'].append(tuple(rows[-1]))
        for i in range(5):
            x=(i-2)*.13
            top=1.83-.035*abs(i-2)
            self.ellipsoid('Hair',(x,top,.285),(.10,.13,.075),c,'Head',20,12,shape=lambda a:Vector((a.x*(.75+.25*(a.y+1)/2),a.y,a.z)))
        accent=tuple(min(1,v*1.13+.015) for v in color(c)[:3])+(1,)
        for i in range(7):
            phi=.20+i*.46
            pts=[(.429*math.sin(t)*math.cos(phi),1.55+.421*math.cos(t),-.015+.363*math.sin(t)*math.sin(phi)) for t in (.32,.56,.79,1.02)]
            self.seam('Hair',pts,accent,'Head',.003)
        if style=='pigtails':
            for sign in (-1,1):
                self.ellipsoid('Hair',(sign*.425,1.49,-.035),(.15,.29,.16),c,shape=lambda a:Vector((a.x*(.8+.2*(a.y+1)/2),a.y,a.z)))
                self.ring('Details',(sign*.423,1.69,-.035),.126,.134,self.p['trim'],'Head',.022,'xz',24)
        elif style=='ponytail':
            self.ellipsoid('Hair',(.055,1.59,-.365),(.18,.31,.19),c,shape=lambda a:Vector((a.x*(.75+.25*(a.y+1)/2),a.y,a.z)))
            self.ring('Details',(.055,1.78,-.32),.115,.105,self.p['trim'],'Head',.022,'xz',24)
        elif style=='bob':
            for sign in (-1,1):self.ellipsoid('Hair',(sign*.326,1.47,-.13),(.115,.276,.22),c)
        elif style=='curls':
            for i in range(7):
                a=math.pi*i/6
                self.ellipsoid('Hair',(.32*math.cos(a),1.80+.10*math.sin(a),.22),(.108,.11,.09),c,segments=18,rings=10)

    def human(self):
        p=self.p;skin='efd0ad';outfit='ffffff' if self.id=='player' else p['outfit'];trim=p['trim']
        def torso_weight(t,point):
            f=max(0,min(1,(point[1]-.76)/.32));return {'Hips':1-f,'Spine':f}
        self.loft('Details' if self.id=='player' else 'Outfit',[(0,.72,0,.255,.20),(0,.78,0,.29,.214),(0,.9,0,.30,.217),(0,1.04,0,.30,.21),(0,1.17,0,.29,.192),(0,1.23,0,.245,.16)],trim if self.id=='player' else outfit,torso_weight,32)
        self.loft('Body',[(0,1.20,0,.11,.105),(0,1.33,0,.12,.108),(0,1.37,0,.13,.11)],skin,'Head',24)
        self.ellipsoid('Body',(0,1.55,0),(.405,.395,.344),skin,shape=lambda a:Vector((a.x*(1-.045*a.y),a.y,a.z)))
        for sign in (-1,1):
            self.ellipsoid('Body',(sign*.395,1.51,-.01),(.071,.10,.065),skin,segments=20)
            self.ellipsoid('Face',(sign*.423,1.51,.029),(.032,.057,.018),'dda98e',segments=16,rings=10)
        if p.get('dress'):
            self.loft('Outfit',[(0,.51,0,.385,.25),(0,.55,0,.39,.256),(0,.66,0,.36,.24),(0,.77,0,.31,.218),(0,.85,0,.285,.21)],p['outfit'],'Hips',40,ruffle=.025)
            self.ring('Details',(0,.545,0),.39,.257,trim,'Hips',.012,'xz',64)
            self.ring('Details',(0,.81,0),.302,.219,trim,'Hips',.016,'xz',48)
        elif p.get('overalls'):
            self.loft('Outfit',[(0,.69,0,.263,.213),(0,.78,0,.30,.222),(0,.91,0,.305,.225)],'ffffff','Hips',32)
            self.ellipsoid('Outfit',(0,1.035,.208),(.18,.187,.025),'ffffff','Spine',24)
            for sign in (-1,1):
                self.seam('Outfit',[(sign*.17,1.11,.20),(sign*.205,1.22,.13),(sign*.20,1.25,0),(sign*.20,1.15,-.19)],'ffffff','Spine',.036)
                self.ellipsoid('Details',(sign*.155,1.165,.237),(.023,.023,.009),'be853e','Spine',16,10)
            self.seam('Details',[(-.09,1.03,.242),(-.09,.94,.249),(0,.916,.252),(.09,.94,.249),(.09,1.03,.242)],'f9e9ad','Spine',.006)
        else:
            # Soft Peter-pan collar and a pocket.
            for sign in (-1,1):self.ellipsoid('Details',(sign*.10,1.218,.143),(.105,.038,.077),trim,'Spine',20,10)
            self.seam('Details',[(.105,1.09,.214),(.105,1.00,.222),(.185,.987,.217),(.23,1.00,.207),(.23,1.09,.199)],trim,'Spine',.006)
            for y in (1.16,1.075,.99):self.ellipsoid('Details',(0,y,.222),(.015,.015,.009),trim,'Spine',12,8)
        if p.get('striped'):
            for y in (.90,1.00,1.10):self.ring('Details',(0,y,0),.304,.219,trim,'Spine',.014,'xz',48)
        self.limbs(skin,outfit,trim)
        self.hair();self.face()
        if p.get('backpack'):
            self.ellipsoid('Accessories',(0,.99,-.25),(.255,.28,.115),'b77d49','Spine',28,16,shape=lambda a:Vector((math.copysign(abs(a.x)**.7,a.x),math.copysign(abs(a.y)**.72,a.y),a.z)))
            self.seam('Details',[(-.18,1.04,-.344),(-.18,.90,-.351),(0,.88,-.367),(.18,.90,-.351),(.18,1.04,-.344)],'e7c585','Spine',.009)
            self.tube('Accessories',[(-.08,1.23,-.26),(-.075,1.29,-.28),(.075,1.29,-.28),(.08,1.23,-.26)],.018,'8e613f','Spine')

    def animal(self):
        bear=self.kind=='bear';fur='b8844c' if bear else 'eee6cd';outfit=self.p['outfit'];cream='f1e5c9'
        self.loft('Body',[(0,.65,0,.29,.24),(0,.78,0,.38,.282),(0,.98,0,.39,.28),(0,1.18,0,.31,.24),(0,1.26,0,.21,.18)],fur,'Spine',32)
        self.loft('Outfit',[(0,.65,0,.30,.25),(0,.78,.01,.39,.292),(0,.92,.01,.39,.287),(0,1.02,.01,.35,.26)],outfit,'Hips',32)
        self.ellipsoid('Outfit',(0,1.07,.26),(.23,.215,.035),outfit,'Spine',28)
        for sign in (-1,1):
            self.seam('Outfit',[(sign*.20,1.12,.27),(sign*.23,1.25,.11),(sign*.23,1.21,-.15),(sign*.20,1.03,-.26)],outfit,'Spine',.035)
            self.ellipsoid('Details',(sign*.18,1.18,.282),(.025,.025,.012),'dfc183','Spine',16,10)
        self.seam('Details',[(-.11,1.025,.30),(-.11,.92,.31),(0,.9,.315),(.11,.92,.31),(.11,1.025,.30)],cream,'Spine',.007)
        self.ellipsoid('Body',(0,1.55,0),(.465,.42,.38),fur,shape=lambda a:Vector((a.x*(1-.06*a.y),a.y,a.z)))
        if bear:
            for sign in (-1,1):
                self.ellipsoid('Body',(sign*.348,1.907,-.025),(.164,.17,.108),fur)
                self.ellipsoid('Face',(sign*.348,1.919,.074),(.09,.096,.024),'d4aa78')
            self.ellipsoid('Face',(0,1.406,.35),(.22,.147,.10),cream)
            self.loft('Accessories',[(0,1.938,0,.272,.253),(0,2.048,0,.266,.247)],cream,'Head',32)
            for x,y,rx in ((-.20,2.083,.17),(0,2.15,.22),(.20,2.083,.17)):
                self.ellipsoid('Accessories',(x,y,0),(rx,.16,.20),cream)
            self.ring('Details',(0,1.975,0),.276,.256,'d9c7a6','Head',.009,'xz')
        else:
            for sign in (-1,1):
                self.ellipsoid('Body',(sign*.195,2.13,-.025),(.116,.44,.11),fur,shape=lambda a:Vector((a.x*(.8+.2*(1-a.y)/2),a.y,a.z)))
                self.ellipsoid('Face',(sign*.195,2.15,.073),(.048,.313,.021),'d7a2a3')
            self.loft('Accessories',[(0,1.895,0,.53,.42),(0,1.939,0,.53,.42),(0,1.945,0,.337,.292),(0,2.101,0,.30,.255),(0,2.128,0,.255,.22)],'d8bf80','Head',48)
            self.loft('Details',[(0,1.965,0,.334,.289),(0,2.011,0,.324,.28)],'6f9990','Head',48)
            for r in (.36,.40,.445,.485):self.ring('Details',(0,1.943,0),r,r*.80,'c6a968','Head',.0035,'xz',64)
            self.ellipsoid('Body',(0,.79,-.285),(.13,.13,.13),cream,'Hips',20)
        self.limbs(fur,outfit,cream);self.face(animal=True)

    def dino(self):
        green='86ac75';belly='e4d9b4'
        self.loft('Body',[(0,.63,0,.24,.23),(0,.78,0,.38,.31),(0,1.02,0,.40,.29),(0,1.20,0,.31,.23),(0,1.32,0,.20,.16)],green,'Spine',32)
        def belly_shape(a):
            x=a.x*.273;y=.98+a.y*.323
            sections=[(.63,.24,.23),(.78,.38,.31),(1.02,.40,.29),(1.20,.31,.23),(1.32,.20,.16)]
            rx,rz=.24,.23
            for lo,hi in zip(sections,sections[1:]):
                if lo[0]<=y<=hi[0]:
                    t=(y-lo[0])/(hi[0]-lo[0]);rx=lo[1]*(1-t)+hi[1]*t;rz=lo[2]*(1-t)+hi[2]*t
                    break
            surface=rz*math.sqrt(max(0,1-(x/rx)**2))
            return Vector((a.x,a.y,surface+.014+.014*a.z))
        self.ellipsoid('Details',(0,.98,0),(.273,.323,1.0),belly,'Spine',segments=32,rings=20,shape=belly_shape)
        self.ellipsoid('Body',(0,1.57,0),(.47,.42,.39),green)
        self.ellipsoid('Face',(0,1.42,.34),(.35,.185,.22),belly)
        for sign in (-1,1):
            self.loft('Details',[(sign*.26,1.91,-.03,.095,.09),(sign*.272,2.02,-.04,.067,.066),(sign*.282,2.12,-.05,.012,.012)],belly,'Head',20)
            self.ellipsoid('Face',(sign*.12,1.46,.547),(.02,.015,.006),'a3a278',segments=12,rings=8)
        self.limbs(green,green,belly);self.face(dino=True)
        self.tube('Body',[(0,.84,-.21),(0,.81,-.40),(0,.79,-.64),(0,.83,-.85),(0,.9,-1.02)],.115,green,'Tail',16)
        self.ellipsoid('Body',(0,.9,-1.02),(.105,.11,.12),green,'Tail',20)
        for z in (-.35,-.56,-.75):
            self.ellipsoid('Details',(0,.94,z),(.055,.09,.08),belly,'Tail',16)
        for side,sign in (("L",-1),("R",1)):
            # Closed thin scalloped wing, with visible joint-aligned ribs.
            bone='Wing_'+side
            pts=[(sign*.26,1.20,-.2),(sign*.51,1.57,-.26),(sign*.88,1.42,-.3),(sign*.75,1.24,-.3),(sign*.82,1.08,-.27),(sign*.58,1.14,-.24),(sign*.47,.99,-.21)]
            d=self.part('Accessories');front=[];back=[]
            for x,y,z in pts:
                front.append(self.vertex('Accessories',(x,y,z+.025),{bone:1},'c98757'))
                back.append(self.vertex('Accessories',(x,y,z-.025),{bone:1},'c98757'))
            d['f'].append(tuple(front));d['f'].append(tuple(reversed(back)))
            for i in range(len(pts)):
                n=(i+1)%len(pts);d['f'].append((front[i],back[i],back[n],front[n]))
            for target in (pts[1],pts[2],pts[4]):self.tube('Body',[pts[0],target],.018,green,bone)

    def wheelchair(self):
        # Authored seated profile uses the exact old hips/knee rest transforms.
        # Chair is bound to Hips with its inverse bind; the mesh rests on the ground.
        # Offsetting by -.09 compensates Author.vertex's seated hips translation.
        b='Hips'; metal='75888c'; fabric='567a8b'
        def pos(p):return (p[0],p[1]-.09,p[2])
        self.ellipsoid('Accessories',pos((0,.78,0)),(.43,.075,.37),fabric,b,32,12,shape=lambda a:Vector((math.copysign(abs(a.x)**.5,a.x),a.y,math.copysign(abs(a.z)**.5,a.z))))
        self.ellipsoid('Accessories',pos((0,1.11,-.36)),(.42,.325,.065),fabric,b,32,16,shape=lambda a:Vector((math.copysign(abs(a.x)**.5,a.x),math.copysign(abs(a.y)**.5,a.y),a.z)))
        for sign in (-1,1):
            x=sign*.53
            self.ring('Accessories',pos((x,.54,-.12)),.49,.49,'3f4d52',b,.047,'yz',64)
            self.ring('Details',pos((x+sign*.061,.54,-.12)),.405,.405,'b7c0b9',b,.018,'yz',64)
            self.ellipsoid('Accessories',pos((x,.54,-.12)),(.055,.08,.08),metal,b,16,10)
            for i in range(12):
                a=math.tau*i/12
                self.seam('Details',[pos((x,.54,-.12)),pos((x,.54+.475*math.cos(a),-.12+.475*math.sin(a)))],'a7b4ad',b,.007)
            self.ring('Accessories',pos((sign*.413,.17,.57)),.13,.13,'4f5e60',b,.035,'yz',32)
            self.tube('Accessories',[pos((sign*.41,1.30,-.41)),pos((sign*.41,.65,-.30)),pos((sign*.41,.32,.53))],.025,metal,b)
            self.tube('Accessories',[pos((sign*.40,.96,-.29)),pos((sign*.40,.96,.36))],.035,metal,b)
            self.tube('Accessories',[pos((sign*.42,1.29,-.36)),pos((sign*.42,1.32,-.52))],.034,'3f4d52',b)
        self.ellipsoid('Accessories',pos((0,.42,.50)),(.31,.04,.15),metal,b,24,12,shape=lambda a:Vector((math.copysign(abs(a.x)**.5,a.x),a.y,math.copysign(abs(a.z)**.5,a.z))))

    def build(self):
        if self.kind in ('bear','rabbit'):self.animal()
        elif self.kind=='dino':self.dino()
        else:self.human()
        if self.kind=='wheelchair':self.wheelchair()

    def make_blender(self):
        collection=bpy.data.collections.new(self.id)
        bpy.context.scene.collection.children.link(collection)
        armdata=bpy.data.armatures.new(self.id+'_Rig')
        arm=bpy.data.objects.new(self.id+'_Armature',armdata);collection.objects.link(arm)
        bpy.context.view_layer.objects.active=arm;arm.select_set(True)
        bpy.ops.object.mode_set(mode='EDIT')
        for name,parent,_,_ in self.bones:
            bone=armdata.edit_bones.new(name)
            mat=self.rest[name]
            bone.head=G2B @ mat.translation
            bone.tail=G2B @ (mat @ Vector((0,.16,0)))
            if parent:bone.parent=armdata.edit_bones[parent]
        bpy.ops.object.mode_set(mode='OBJECT');arm.select_set(False)
        self.objects.append(arm)
        material_cache={}
        rawgroups=[]
        for group,d in self.parts.items():
            mesh=bpy.data.meshes.new(self.id+'_'+group)
            mesh.from_pydata(d['v'],[],d['f']);mesh.update()
            # Recalculate winding from the closed authored surfaces.
            bm=bmesh.new();bm.from_mesh(mesh)
            bmesh.ops.triangulate(bm,faces=list(bm.faces),quad_method='BEAUTY',ngon_method='BEAUTY')
            bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
            for polygon in mesh.polygons:polygon.use_smooth=True
            mesh.update()
            # Preserve smooth curved shading while splitting the few very sharp
            # cap/strap/closed-tube corners. A normal may never face into its face.
            split=[tuple(n.vector) for n in mesh.corner_normals]
            for polygon in mesh.polygons:
                for li in polygon.loop_indices:
                    if Vector(split[li]).dot(polygon.normal)<.15:
                        split[li]=tuple(polygon.normal)
            mesh.normals_split_custom_set(split)
            obj=bpy.data.objects.new(group,mesh);collection.objects.link(obj);obj.parent=arm
            self.objects.append(obj)
            for name,_,_,_ in self.bones:
                vg=obj.vertex_groups.new(name=name)
                for i,w in enumerate(d['w']):
                    if w.get(name,0)>.000001:vg.add([i],w[name],'REPLACE')
            mod=obj.modifiers.new('Smooth skin','ARMATURE');mod.object=arm
            uv=mesh.uv_layers.new(name='UVMap')
            ca=mesh.color_attributes.new(name='Pigment',type='FLOAT_COLOR',domain='POINT')
            for i,cc in enumerate(d['c']):ca.data[i].color=linear(cc)
            for loop in mesh.loops:uv.data[loop.index].uv=d['uv'][loop.vertex_index]
            mat=bpy.data.materials.new(self.id+'_'+group);mat.use_nodes=True
            bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
            bsdf.inputs['Roughness'].default_value=.33 if group=='Eyes' else .83
            pigment=mat.node_tree.nodes.new('ShaderNodeVertexColor');pigment.layer_name='Pigment'
            if self.id=='player' and group=='Outfit':
                mix=mat.node_tree.nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;mix.inputs[2].default_value=linear(color(self.p['outfit']))
                mat.node_tree.links.new(pigment.outputs['Color'],mix.inputs[1]);mat.node_tree.links.new(mix.outputs[0],bsdf.inputs['Base Color'])
            else:mat.node_tree.links.new(pigment.outputs['Color'],bsdf.inputs['Base Color'])
            mesh.materials.append(mat)
            morph_names={'Blink':'blink'} if group=='Eyes' else {'Smile':'smile','Talk':'talk'} if group=='Face' else {}
            if morph_names:
                obj.shape_key_add(name='Basis')
                for shape_name,key in morph_names.items():
                    shape=obj.shape_key_add(name=shape_name)
                    for i,p in enumerate(d[key]):shape.data[i].co=p
                    shape.value=0.0
                obj.active_shape_key_index=0
            mesh.calc_loop_triangles()
            verts=[];normals=[];colors=[];uvs=[];weights=[];bones=[];blinks=[]
            morphs={name:[] for name in morph_names}
            bone_indices={name:i for i,(name,_,_,_) in enumerate(self.bones)}
            for triangle in mesh.loop_triangles:
                # Godot front faces are clockwise; Blender are counter-clockwise.
                for li in reversed(triangle.loops):
                    loop=mesh.loops[li];vi=loop.vertex_index
                    vv=B2G @ mesh.vertices[vi].co
                    nn=B2G.to_3x3() @ mesh.corner_normals[li].vector
                    verts.extend(round(x,7) for x in vv);normals.extend(round(x,7) for x in nn)
                    colors.extend(d['c'][vi]);uvs.extend(d['uv'][vi])
                    ww=sorted(d['w'][vi].items(),key=lambda q:-q[1])[:4]
                    total=sum(w for _,w in ww)
                    ww=[(n,w/total) for n,w in ww]+[('Hips',0)]*(4-len(ww))
                    bones.extend(bone_indices[n] for n,_ in ww);weights.extend(round(w,7) for _,w in ww)
                    blinks.extend(round(x,7) for x in (B2G @ Vector(d['blink'][vi])))
                    for shape_name,key in morph_names.items():
                        morphs[shape_name].extend(round(x,7) for x in (B2G @ Vector(d[key][vi])))
            rawgroups.append(dict(name=group,vertices=verts,normals=normals,colors=colors,uv=uvs,bones=bones,weights=weights,blink=blinks if group=='Eyes' else [],morphs=morphs,tint=self.p['outfit'] if self.id=='player' and group=='Outfit' else 'ffffff',roughness=.33 if group=='Eyes' else .83))
        raw=dict(schema_version=3,id=self.id,art_revision='storybook-character-v3',profile=self.p,bones=[dict(name=n,parent=p,origin=o,rotation=r) for n,p,o,r in self.bones],groups=rawgroups)
        (DATA/(self.id+'.json')).write_text(json.dumps(raw,separators=(',',':')),encoding='utf-8')
        bpy.ops.object.select_all(action='DESELECT')
        for o in self.objects:o.select_set(True)
        bpy.context.view_layer.objects.active=arm
        bpy.ops.export_scene.gltf(filepath=str(OUT/(self.id+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_yup=True,export_apply=False,export_extras=True,export_materials='EXPORT')
        bpy.ops.object.select_all(action='DESELECT')
        collection.hide_viewport=True;collection.hide_render=True
        meshes=[o.data for o in self.objects if o.type=='MESH']
        return dict(id=self.id,display_name=self.p['name'],kind=self.kind,meshes=len(meshes),vertices=sum(len(m.vertices) for m in meshes),triangles=sum(len(m.loop_triangles) for m in meshes),bones=len(self.bones),smooth_weight_vertices=sum(1 for d in self.parts.values() for w in d['w'] if sum(v>.001 for v in w.values())>1),source_glb=f'{self.id}.glb',runtime_source=f'source/{self.id}.json',blend_shapes=['Blink','Smile','Talk'],source_reference='existing sourced character profile; original project-authored mesh',seated_rest=self.kind=='wheelchair')


def main():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    assets=[]
    for id,profile in PROFILES.items():
        author=Author(id,profile);author.build();assets.append(author.make_blender())
        print('CHARACTER_V3',id,assets[-1],flush=True)
    first=bpy.data.collections.get('player');first.hide_viewport=False;first.hide_render=False
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'storybook_characters_v3.blend'))
    manifest=dict(schema_version=3,art_revision='storybook-character-v3',status='authored_pending_engine_validation',creator='Project-authored parametric Blender meshes',license='Original project asset; no external mesh library',direction='Rounded storybook dolls; tailored clothes, stitched trims, sculpted hair, warm restrained pigment, smooth joint weights',source_script='../../../scripts/build_character_art_v3.py',source_script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),editable_source='storybook_characters_v3.blend',technical=dict(coordinates='Godot +Y up +Z front; Blender coordinate conversion in source',runtime='Godot baked ArrayMesh with Skin on original P1 bones',scale='matches existing P1 contact bones in metres',weights='up to four normalized influences; blended elbow knee waist loops',texture='vertex pigment plus UVs; no image texture dependency',collision='unchanged existing CharacterBody3D capsule',lod='single authored LOD for near-camera small cast; no automatic claim of mobile acceptance'),assets=assets)
    (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')


if __name__=='__main__':main()

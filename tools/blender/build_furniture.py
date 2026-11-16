"""Builds the Artist furniture (assets/models/artist_furniture/*.glb and their icons) with Blender.
Run: python3 -I tools/blender/build_furniture.py   (needs the bpy package, pip install bpy==5.1.0).
Units are Kenney raw units (the room designer draws them furniture_scale times).
"""
import bpy, bmesh, math, sys
from mathutils import Vector
import os,sys
HERE=os.path.dirname(os.path.abspath(__file__));TEX=os.path.join(HERE,'textures')+'/'
bpy.ops.wm.read_factory_settings(use_empty=True)
sc=bpy.context.scene
_mc={}
def mat(name,col,rough=0.5,metal=0,wood=None,alpha=1.0):
    import colorsys
    key=(name,tuple(round(c,3) for c in col[:3]),rough,metal,bool(wood),alpha)
    if key in _mc: return _mc[key]
    h,sa,v=colorsys.rgb_to_hsv(*col[:3]);col=colorsys.hsv_to_rgb(h,min(1,sa*1.55+0.05*(sa>0.05)),min(1,v*0.92))
    m=bpy.data.materials.new(name);m.use_nodes=True
    b=m.node_tree.nodes['Principled BSDF'];b.inputs['Roughness'].default_value=rough;b.inputs['Metallic'].default_value=metal
    if wood:
        n=m.node_tree.nodes;l=m.node_tree.links
        t=n.new('ShaderNodeTexImage');t.image=bpy.data.images.load(TEX+('wood_oak.png' if col[0]>0.5 else 'wood_walnut.png'))
        l.new(t.outputs['Color'],b.inputs['Base Color'])
    else:
        b.inputs['Base Color'].default_value=(*col,1)
    if alpha<1:
        b.inputs['Alpha'].default_value=alpha;b.inputs['Transmission Weight'].default_value=0.9;b.inputs['IOR'].default_value=1.45
    _mc[key]=m
    return m
def box(name,loc,size,m,bevel=0.008):
    bpy.ops.mesh.primitive_cube_add(location=loc);o=bpy.context.object;o.name=name
    o.scale=(size[0]/2,size[1]/2,size[2]/2);bpy.ops.object.transform_apply(scale=True)
    if bevel:
        bv=o.modifiers.new('b','BEVEL');bv.width=bevel;bv.segments=2
    o.data.materials.append(m);bpy.ops.object.shade_smooth() if bevel>0.005 else bpy.ops.object.shade_flat()
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.uv.cube_project(cube_size=1);bpy.ops.object.mode_set(mode='OBJECT')
    return o
oak=mat('oak',(0.62,0.40,0.2),0.45,wood=True);dark=mat('walnut',(0.32,0.18,0.1),0.4,wood=True)
brass=mat('brass',(0.8,0.6,0.25),0.25,1);steel=mat('steel',(0.7,0.7,0.72),0.3,1);cream=mat('cream',(0.85,0.8,0.65),0.5)
glass=mat('glass',(0.9,1,1),0.05,alpha=0.15)
# counter: x length .9, y depth .4, z up .42 (Kenney raw units)
def rbox(name,loc,size,m,r=0.02,seg=4):
    return box(name,loc,size,m,bevel=r) if False else _rb(name,loc,size,m,r,seg)
def _rb(name,loc,size,m,r,seg):
    bpy.ops.mesh.primitive_cube_add(location=loc);o=bpy.context.object;o.name=name
    o.scale=(size[0]/2,size[1]/2,size[2]/2);bpy.ops.object.transform_apply(scale=True)
    bv=o.modifiers.new('b','BEVEL');bv.width=r;bv.segments=seg;bv.limit_method='NONE'
    bpy.ops.object.modifier_apply(modifier='b')
    o.data.materials.append(m);bpy.ops.object.shade_smooth()
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.uv.cube_project(cube_size=0.5);bpy.ops.object.mode_set(mode='OBJECT')
    return o
M=0.43;D=0.45;H=0.40
leather=mat('leather',(0.12,0.2,0.15),0.35)
def seg(x,y,kind='straight',rot=0):
    """one counter module at grid cell (x,y); front faces -y. kind: straight,end_l,end_r,register"""
    ox=x*M;oy=y*M
    parts=[]
    parts.append(rbox('plinth',(ox,oy,0.015),(M,D-0.02,0.03),dark,0.006,3))
    parts.append(rbox('body',(ox,oy,0.2),(M-0.004,D-0.04,0.33),dark,0.01,3))
    if kind in('straight','register','end_l','end_r'):
        parts.append(rbox('frame',(ox,oy-D/2+0.036,0.2),(M-0.05,0.02,0.28),oak,0.007,3))
        parts.append(rbox('inset',(ox,oy-D/2+0.026,0.2),(M-0.11,0.014,0.21),mat('mid',(0.45,0.27,0.14),0.4),0.008,3))
        parts.append(rbox('inner',(ox,oy-D/2+0.022,0.2),(M-0.17,0.012,0.15),oak,0.01,3))
    parts.append(rbox('top',(ox,oy-0.01,0.385),(M,D+0.03,0.026),oak,0.009,3))
    parts.append(rbox('inlay',(ox,oy-0.01,0.3995),(M-0.05,D-0.03,0.004),leather,0.002,2))
    if kind=='end_l': parts.append(rbox('endcap',(ox-M/2,oy-0.01,0.2),(0.025,D+0.03,0.4),oak,0.008,3))
    if kind=='end_r': parts.append(rbox('endcap',(ox+M/2,oy-0.01,0.2),(0.025,D+0.03,0.4),oak,0.008,3))
    return parts
def corner(x,y):
    ox=x*M;oy=y*M
    rbox('plinth',(ox,oy,0.015),(M,M,0.03),dark,0.006,3)
    rbox('body',(ox,oy,0.2),(M-0.004,M-0.004,0.33),dark,0.01,3)
    rbox('top',(ox,oy,0.385),(M+0.03,M+0.03,0.026),oak,0.009,3)
    rbox('inlay',(ox,oy,0.3995),(M-0.02,M-0.02,0.004),leather,0.002,2)
    rbox('post',(ox,oy,0.2),(0.04,0.04,0.34),oak,0.012,3)
def register(x,y):
    ox=x*M;oy=y*M;z0=0.4
    rbox('rbody',(ox,oy,z0+0.035),(0.2,0.2,0.07),cream,0.03,4)
    # drawer at the front, a little open, with notes
    rbox('rdrawer',(ox,oy-0.115,z0+0.025),(0.17,0.05,0.035),steel,0.008,3)
    rbox('rnotes',(ox,oy-0.125,z0+0.045),(0.14,0.04,0.01),mat('notes',(0.5,0.7,0.45),0.6),0.002,2)
    # sloped keypad with a grid of buttons, facing the front
    kp=rbox('rkeys',(ox,oy-0.04,z0+0.09),(0.19,0.11,0.03),cream,0.012,3);kp.rotation_euler=(math.radians(-22),0,0)
    for i in range(4):
        for j in range(3):
            bx=ox-0.06+i*0.04;by=oy-0.062+j*0.028
            rbox('key',(bx,by-0.003*j,z0+0.105+j*0.011),(0.028,0.02,0.01),mat('key',(0.25,0.25,0.28) if (i+j)%5 else (0.8,0.3,0.2),0.4),0.004,2)
    # display on a short pole, facing the front
    rbox('rpole',(ox,oy+0.05,z0+0.11),(0.025,0.025,0.08),steel,0.008,3)
    rbox('rscreen',(ox,oy+0.045,z0+0.17),(0.15,0.025,0.075),mat('scr',(0.1,0.12,0.12),0.2),0.008,3)
    rbox('rglow',(ox,oy+0.031,z0+0.17),(0.12,0.004,0.05),mat('glow',(0.4,0.85,0.55),0.2),0.002,2)
    # receipt roll
    bpy.ops.mesh.primitive_cylinder_add(vertices=20,radius=0.03,depth=0.07,location=(ox+0.07,oy+0.07,z0+0.1),rotation=(0,math.radians(90),0))
    bpy.context.object.data.materials.append(mat('paper',(0.95,0.95,0.9),0.7));bpy.ops.object.shade_smooth()
def bottle(x,y,z,col):
    bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=0.018,depth=0.07,location=(x,y,z+0.035));o=bpy.context.object
    o.data.materials.append(mat('b',col,0.2));bpy.ops.object.shade_smooth()
    bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=0.008,depth=0.03,location=(x,y,z+0.085));p=bpy.context.object
    p.data.materials.append(mat('c',col,0.2));bpy.ops.object.shade_smooth()
chrome=mat('chrome',(0.75,0.77,0.8),0.22,1)
def arc_glass(ox,oy,W,z0,z1,r):
    """front glass with a round profile: a quarter circle from the base line up and back"""
    import bmesh
    me=bpy.data.meshes.new('arc');o=bpy.data.objects.new('arc_glass',me);bpy.context.collection.objects.link(o)
    bm=bmesh.new();n=10;rows=[]
    for k in range(n+1):
        t=k/n*math.pi/2
        y=oy-D/2+0.03+r-r*math.cos(t) -r*0 ; z=z0+(z1-z0)*math.sin(t)
        y=oy-D/2+0.02+r*(1-math.sin(t))
        rows.append((bm.verts.new((ox-W/2+0.01,y,z)),bm.verts.new((ox+W/2-0.01,y,z))))
    for k in range(n): bm.faces.new((rows[k][0],rows[k][1],rows[k+1][1],rows[k+1][0]))
    bm.to_mesh(me);bm.free()
    so=o.modifiers.new('s','SOLIDIFY');so.thickness=0.006
    o.data.materials.append(glass);bpy.context.view_layer.objects.active=o;bpy.ops.object.shade_smooth()
def deli_case(x,y,w=2):
    """shop display case: steel frame, back panel, curved glass front, shelves with goods"""
    ox=x*M+(w-1)*M/2;oy=y*M;W=w*M
    rbox('cplinth',(ox,oy,0.015),(W,D-0.02,0.03),chrome,0.012,4)
    rbox('cbase',(ox,oy,0.115),(W-0.004,D-0.04,0.17),chrome,0.03,5)
    rbox('cstrip',(ox,oy-D/2+0.02,0.14),(W-0.06,0.006,0.03),mat('lamp',(1,0.95,0.8),0.3),0.002,2)
    rbox('cback',(ox,oy+D/2-0.03,0.3),(W-0.01,0.012,0.3),chrome,0.01,4)
    for sx in(-1,1): rbox('cside',(ox+sx*(W/2-0.01),oy,0.3),(0.012,D-0.06,0.3),glass,0.006,3)
    rbox('ctop',(ox,oy+0.01,0.455),(W,D-0.04,0.025),chrome,0.012,5)
    arc_glass(ox,oy,W,0.2,0.44,0.2)
    for z in(0.2,0.33): rbox('shelf',(ox,oy+0.03,z),(W-0.03,D-0.12,0.008),glass,0.002,2)
    cols=[(0.75,0.15,0.1),(0.2,0.45,0.2),(0.85,0.7,0.15),(0.2,0.3,0.6)]
    for i in range(w*3):
        bottle(ox-W/2+0.07+i*(W-0.14)/(w*3-1),oy+0.02,0.204,cols[i%4])
    for i in range(w*2):
        rbox('pack',(ox-W/2+0.1+i*(W-0.2)/(w*2-1),oy+0.04,0.334+0.025),(0.07,0.07,0.05),mat('p',cols[(i+1)%4],0.5),0.01,3)
    rbox('stand',(ox,oy-0.12,0.28),(0.08,0.004,0.04),brass,0.001,2)
import mathutils
def cyl(loc,r,h,m,v=20,rot=(0,0,0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=v,radius=r,depth=h,location=loc,rotation=rot);o=bpy.context.object
    o.data.materials.append(m);bpy.ops.object.shade_smooth();return o
def sph(loc,r,m,sc=(1,1,1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,radius=r,location=loc);o=bpy.context.object;o.scale=sc
    o.data.materials.append(m);bpy.ops.object.shade_smooth();return o
green=mat('leaf',(0.18,0.45,0.2),0.5);green2=mat('leaf2',(0.3,0.55,0.25),0.5)
terra=mat('terra',(0.7,0.35,0.22),0.7);soil=mat('soil',(0.15,0.09,0.06),0.9)
green2=mat('leaf2',(0.3,0.55,0.25),0.5)
def pot_plant(x,y):
    cyl((x,y,0.06),0.07,0.12,terra,24);cyl((x,y,0.125),0.075,0.02,terra,24);cyl((x,y,0.133),0.06,0.01,soil,20)
    import random;random.seed(4)
    for i in range(9):
        a=i/9*math.tau;sph((x+0.035*math.cos(a),y+0.035*math.sin(a),0.2+0.04*(i%3)),0.05,green if i%2 else green2,(0.5,0.5,1.4))
        bpy.context.object.rotation_euler=(0.4*math.sin(a),-0.4*math.cos(a),0)
    sph((x,y,0.27),0.06,green2,(0.9,0.9,1.3))
def tall_plant(x,y):
    cyl((x,y,0.07),0.06,0.14,mat('white',(0.9,0.88,0.82),0.4),24);cyl((x,y,0.145),0.05,0.01,soil,20)
    for i in range(10):
        a=i/10*math.tau+0.3
        bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=0.022,depth=0.36,location=(x+0.04*math.cos(a),y+0.04*math.sin(a),0.31));o=bpy.context.object
        o.rotation_euler=(0.35*math.sin(a),-0.35*math.cos(a),0);o.data.materials.append(green if i%2 else green2);bpy.ops.object.shade_smooth()
def frame(x,y,z,w,h,art,rot=0):
    f=rbox('frame',(x,y,z),(w,0.02,h),mat('fr',(0.25,0.15,0.08),0.4),0.008,3)
    rbox('mat',(x,y-0.008,z),(w-0.03,0.012,h-0.03),mat('matt',(0.93,0.9,0.82),0.8),0.003,2)
    art(x,y-0.016,z,w,h)
def art_sun(x,y,z,w,h):
    rbox('sky',(x,y,z),(w-0.07,0.006,h-0.07),mat('sky',(0.5,0.7,0.85),0.6),0.001,2)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=0.03,location=(x+w*0.12,y-0.005,z+h*0.1));o=bpy.context.object;o.scale=(1,0.2,1);o.data.materials.append(mat('sun',(0.95,0.8,0.25),0.5))
    rbox('hill',(x,y-0.004,z-h*0.22),(w-0.07,0.006,h*0.28),mat('hill',(0.3,0.55,0.3),0.7),0.001,2)
def art_stripes(x,y,z,w,h):
    for i,c in enumerate([(0.8,0.2,0.2),(0.95,0.75,0.2),(0.2,0.4,0.7)]):
        rbox('st',(x-w*0.22+i*w*0.22,y,z),(w*0.2,0.006,h-0.07),mat('st',c,0.6),0.001,2)
def art_portrait(x,y,z,w,h):
    rbox('bg',(x,y,z),(w-0.07,0.006,h-0.07),mat('bg',(0.35,0.2,0.2),0.6),0.001,2)
    sph((x,y-0.008,z+h*0.1),0.04,mat('face',(0.9,0.72,0.58),0.6),(1,0.3,1.15))
    rbox('suit',(x,y-0.007,z-h*0.2),(w*0.5,0.006,h*0.3),mat('suit',(0.1,0.1,0.15),0.6),0.01,2)
def clock(x,y,z):
    cyl((x,y,z),0.07,0.025,mat('rim',(0.2,0.12,0.06),0.4),32,(math.pi/2,0,0))
    cyl((x,y-0.014,z),0.06,0.005,mat('face',(0.95,0.93,0.85),0.6),32,(math.pi/2,0,0))
    rbox('h1',(x,y-0.02,z+0.02),(0.006,0.004,0.04),mat('hand',(0.05,0.05,0.05),0.5),0.001,2)
    r=rbox('h2',(x+0.015,y-0.02,z+0.005),(0.006,0.004,0.03),mat('hand',(0.05,0.05,0.05),0.5),0.001,2);r.rotation_euler=(0,math.radians(60),0)
def safe(x,y):
    m=mat('safe',(0.22,0.27,0.3),0.35,1)
    rbox('sbody',(x,y,0.15),(0.32,0.3,0.3),m,0.02,4)
    rbox('sdoor',(x,y-0.155,0.15),(0.27,0.012,0.25),mat('sd',(0.3,0.36,0.4),0.3,1),0.015,4)
    cyl((x,y-0.172,0.17),0.04,0.015,brass,28,(math.pi/2,0,0));cyl((x,y-0.172,0.17),0.012,0.02,mat('dk',(0.05,0.05,0.05),0.4),16,(math.pi/2,0,0))
    rbox('handle',(x+0.075,y-0.175,0.12),(0.05,0.012,0.012),brass,0.004,3)
    for sx in(-1,1): rbox('hinge',(x+sx*0.14,y-0.16,0.15),(0.01,0.012,0.18),brass,0.003,2)
    for sx in(-1,1): rbox('foot',(x+sx*0.12,y,0.01),(0.05,0.25,0.02),mat('ft',(0.1,0.1,0.1),0.5),0.005,2)
def shelf_unit(x,y):
    wood=oak
    for sx in(-1,1): rbox('side',(x+sx*0.19,y,0.25),(0.025,0.2,0.5),wood,0.006,3)
    rbox('back',(x,y+0.09,0.25),(0.4,0.012,0.5),dark,0.004,2)
    cols=[(0.75,0.15,0.1),(0.2,0.45,0.2),(0.85,0.7,0.15),(0.2,0.3,0.6),(0.7,0.4,0.6)]
    for k,z in enumerate((0.02,0.18,0.34,0.5)):
        rbox('board',(x,y,z),(0.4,0.2,0.02),wood,0.006,3)
        if k<3:
            for i in range(5):
                if (i+k)%4==3: continue
                kind=(i+k)%3
                px=x-0.15+i*0.075
                if kind==0: rbox('box',(px,y-0.01,z+0.045),(0.06,0.1,0.07),mat('g',cols[(i+k)%5],0.5),0.006,3)
                elif kind==1: cyl((px,y-0.01,z+0.05),0.022,0.08,mat('g',cols[(i+k)%5],0.25),16)
                else:
                    cyl((px,y-0.01,z+0.035),0.03,0.05,mat('g',cols[(i+k)%5],0.4),16)
def file_cabinet(x,y):
    m=mat('fcab',(0.45,0.5,0.52),0.45,0.8)
    rbox('fbody',(x,y,0.2),(0.2,0.24,0.4),m,0.012,3)
    for i,z in enumerate((0.07,0.2,0.33)):
        rbox('fdrawer',(x,y-0.121,z),(0.17,0.008,0.11),mat('fd',(0.5,0.55,0.57),0.4,0.8),0.008,3)
        rbox('fhandle',(x,y-0.13,z+0.02),(0.07,0.01,0.012),steel,0.004,3)
        rbox('flabel',(x,y-0.128,z-0.02),(0.05,0.004,0.02),mat('lab',(0.95,0.95,0.85),0.7),0.001,2)
def desk_lamp(x,y):
    cyl((x,y,0.008),0.05,0.016,mat('lb',(0.1,0.1,0.1),0.4),24)
    cyl((x,y,0.1),0.006,0.2,brass,10)
    cone=bpy.ops.mesh.primitive_cone_add(vertices=24,radius1=0.07,radius2=0.03,depth=0.07,location=(x,y,0.215));o=bpy.context.object;o.data.materials.append(mat('shade',(0.2,0.45,0.35),0.4));bpy.ops.object.shade_smooth()
def wastebin(x,y):
    cyl((x,y,0.075),0.065,0.15,mat('bin',(0.3,0.32,0.35),0.4,0.7),24)
# ground row 1: floor objects; wall row (frames on a wall panel) behind

import os
_cm={}
def card_mat(name,png):
    if name in _cm: return _cm[name]
    m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;l=m.node_tree.links
    b=n['Principled BSDF'];b.inputs['Roughness'].default_value=0.6
    t=n.new('ShaderNodeTexImage');t.image=bpy.data.images.load(TEX+png);t.interpolation='Linear'
    l.new(t.outputs['Color'],b.inputs['Base Color']);l.new(t.outputs['Alpha'],b.inputs['Alpha'])
    m.blend_method='CLIP' if hasattr(m,'blend_method') else None
    _cm[name]=m
    return m
def card(loc,size,rotz,tilt,m):
    bpy.ops.mesh.primitive_plane_add(size=1,location=loc);o=bpy.context.object
    o.scale=(size,size,size);o.rotation_euler=(math.pi/2-tilt,0,rotz)
    # uv: default plane uv OK; shift origin so card grows upward from loc
    o.data.materials.append(m);return o
fern=card_mat('fern','leaf_fern.png');bush=card_mat('bush','leaf_bush.png');big=card_mat('big','leaf_big.png')
def fern_plant(x,y,sz=0.36):
    cyl((x,y,0.05),0.055,0.10,terra,24);cyl((x,y,0.105),0.06,0.014,terra,24);cyl((x,y,0.113),0.05,0.006,soil,20)
    for i in range(4): card((x,y,0.1+sz/2),sz,i*math.pi/4+0.2,0.12*(i%2),fern)
def ficus(x,y):
    cyl((x,y,0.06),0.07,0.12,mat('white',(0.9,0.85,0.75),0.4),24);cyl((x,y,0.125),0.06,0.01,soil,20)
    cyl((x,y,0.32),0.012,0.40,mat('trunk',(0.35,0.2,0.1),0.7),10)
    for i,(dz,sz) in enumerate(((0.45,0.34),(0.55,0.3),(0.38,0.28))):
        for k in range(3): card((x,y,dz),sz,k*math.pi/3+i*0.5,0.0,bush)
def big_leaf_plant(x,y):
    cyl((x,y,0.06),0.075,0.12,mat('blue',(0.2,0.4,0.75),0.4),24);cyl((x,y,0.125),0.065,0.01,soil,20)
    for i in range(5):
        a=i/5*math.tau;card((x+0.03*math.cos(a),y+0.03*math.sin(a),0.12+0.17),0.34,a+math.pi/2,0.35,big)
def armchair(x,y,col):
    m=mat('sofa',col,0.7)
    rbox('seat',(x,y,0.08),(0.22,0.2,0.1),m,0.04,5)
    rbox('back',(x,y+0.085,0.17),(0.22,0.05,0.2),m,0.04,5)
    for sx in(-1,1): rbox('arm',(x+sx*0.1,y,0.12),(0.04,0.2,0.16),m,0.018,4)
    rbox('cush',(x,y-0.01,0.14),(0.15,0.15,0.04),mat('cu',(0.95,0.8,0.2),0.7),0.02,4)
    for sx in(-1,1):
        for sy in(-1,1): cyl((x+sx*0.09,y+sy*0.08,0.015),0.012,0.03,dark,10)
def sofa2(x,y,col):
    m=mat('sofa',col,0.7)
    rbox('seat',(x,y,0.08),(0.4,0.2,0.1),m,0.04,5)
    rbox('back',(x,y+0.085,0.17),(0.4,0.05,0.2),m,0.04,5)
    for sx in(-1,1): rbox('arm',(x+sx*0.19,y,0.12),(0.04,0.2,0.16),m,0.018,4)
    for sx in(-1,1): rbox('cush',(x+sx*0.09,y-0.01,0.14),(0.16,0.14,0.04),mat('cu2',(0.9,0.35,0.3),0.7),0.02,4)
    for sx in(-1,1):
        for sy in(-1,1): cyl((x+sx*0.17,y+sy*0.08,0.015),0.012,0.03,dark,10)
def coffee_table(x,y):
    cyl((x,y,0.1),0.1,0.015,oak,32)
    for a in range(3): 
        ang=a*math.tau/3;cyl((x+0.07*math.cos(ang),y+0.07*math.sin(ang),0.05),0.008,0.1,dark,8)
    cyl((x,y,0.075),0.07,0.008,dark,24)
def chair(x,y,col):
    m=mat('ch',col,0.6)
    rbox('seat',(x,y,0.09),(0.1,0.1,0.015),m,0.01,3)
    rbox('back',(x,y+0.045,0.15),(0.1,0.012,0.12),m,0.01,3)
    for sx in(-1,1):
        for sy in(-1,1): cyl((x+sx*0.042,y+sy*0.042,0.045),0.007,0.09,dark,8)
def stool(x,y):
    cyl((x,y,0.11),0.05,0.02,mat('st',(0.85,0.25,0.2),0.5),24)
    for a in range(3):
        ang=a*math.tau/3;cyl((x+0.03*math.cos(ang),y+0.03*math.sin(ang),0.05),0.006,0.1,steel,8)
def floor_lamp(x,y):
    cyl((x,y,0.008),0.05,0.016,mat('lb',(0.1,0.1,0.1),0.4),24);cyl((x,y,0.2),0.007,0.4,brass,10)
    bpy.ops.mesh.primitive_cone_add(vertices=28,radius1=0.1,radius2=0.05,depth=0.11,location=(x,y,0.43));o=bpy.context.object;o.data.materials.append(mat('shade',(0.98,0.8,0.3),0.5));bpy.ops.object.shade_smooth()
def tall_books(x,y):
    for sx in(-1,1): rbox('side',(x+sx*0.19,y,0.4),(0.025,0.18,0.8),oak,0.006,3)
    rbox('back',(x,y+0.08,0.4),(0.4,0.012,0.8),dark,0.004,2)
    cols=[(0.8,0.15,0.1),(0.15,0.4,0.75),(0.9,0.7,0.1),(0.15,0.55,0.3),(0.6,0.2,0.6)]
    for k,z in enumerate((0.02,0.2,0.38,0.56,0.78)):
        rbox('board',(x,y,z),(0.4,0.18,0.02),oak,0.006,3)
        if k<4:
            px=x-0.17
            for i in range(11):
                w=random.choice((0.022,0.03,0.04));hh=random.choice((0.11,0.13,0.15))
                rbox('book',(px+w/2,y,z+0.01+hh/2),(w,0.13,hh),mat('bk',cols[(i+k)%5],0.5),0.003,2);px+=w+0.002
                if px>x+0.17: break
def rug(x,y):
    cyl((x,y,0.004),0.22,0.008,mat('rug1',(0.75,0.15,0.2),0.9),48);cyl((x,y,0.006),0.17,0.008,mat('rug2',(0.95,0.8,0.25),0.9),48);cyl((x,y,0.008),0.11,0.008,mat('rug3',(0.15,0.35,0.7),0.9),48)

sc.render.engine='CYCLES';sc.cycles.device='CPU';sc.cycles.use_denoising=True
sc.world=bpy.data.worlds.new('w');sc.world.use_nodes=True;sc.world.node_tree.nodes['Background'].inputs[0].default_value=(0.9,0.93,1,1);sc.world.node_tree.nodes['Background'].inputs[1].default_value=1.2
bpy.ops.object.light_add(type='SUN',location=(2,-3,4));_s=bpy.context.object;_s.data.energy=3.5;_s.rotation_euler=(math.radians(55),0,math.radians(-25))
sc.view_settings.view_transform='Standard'
import random;random.seed(3)
import os,mathutils
OUT=os.path.join(HERE,'..','..','assets','models','artist_furniture')+'/'
os.makedirs(OUT,exist_ok=True);ICONS=OUT+'icons/';os.makedirs(ICONS,exist_ok=True)
def export(name,fn):
    before=set(bpy.data.objects)
    fn()
    new=[o for o in bpy.data.objects if o not in before]
    meshes=[o for o in new if o.type=='MESH']
    for o in meshes:
        bpy.context.view_layer.objects.active=o
        for md in list(o.modifiers):
            try: bpy.ops.object.modifier_apply(modifier=md.name)
            except Exception: pass
    bpy.context.view_layer.update()
    pts=[o.matrix_world@mathutils.Vector(c) for o in meshes for c in o.bound_box]
    mn=mathutils.Vector((min(p.x for p in pts),min(p.y for p in pts),min(p.z for p in pts)));mx=mathutils.Vector((max(p.x for p in pts),max(p.y for p in pts),max(p.z for p in pts)))
    off=mathutils.Vector(((mn.x+mx.x)/2,(mn.y+mx.y)/2,mn.z))
    for o in meshes: o.location=o.location-off
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes: o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=OUT+name+'.glb',export_format='GLB',use_selection=True,export_apply=True)
    faces=sum(len(o.data.polygons) for o in meshes)
    print('EXPORT',name,len(meshes),'meshes',faces,'faces',round(mx.x-mn.x,3),round(mx.y-mn.y,3),round(mx.z-mn.z,3))
    icon(name,mx-mn)
    for o in new: bpy.data.objects.remove(o,do_unlink=True)

def icon(name,size):
    sc=bpy.context.scene
    for o in [o for o in bpy.data.objects if o.name.startswith('ICONCAM')]: bpy.data.objects.remove(o,do_unlink=True)
    cd=bpy.data.cameras.new('ICONCAM');cd.type='ORTHO'
    w,h=max(size.x,0.02),max(size.z,0.02)
    cd.ortho_scale=max(w/141*1.1*141,h/68*1.1*141/1.0,w*1.1)
    cd.ortho_scale=max(w*1.12,h*1.12*141/68)
    co=bpy.data.objects.new('ICONCAM',cd);bpy.context.collection.objects.link(co)
    co.location=(0,-3,size.z/2);co.rotation_euler=(math.pi/2,0,0)
    prev=sc.camera;sc.camera=co
    sc.render.resolution_x=282;sc.render.resolution_y=136;sc.render.film_transparent=True;sc.cycles.samples=12
    sc.render.filepath=ICONS+name+'_big.png'
    # hide scene ground and wall objects during icon
    hid=[]
    for o in hid: o.hide_render=True
    bpy.ops.render.render(write_still=True)
    for o in hid: o.hide_render=False
    sc.camera=prev
    from PIL import Image
    im=Image.open(ICONS+name+'_big.png').convert('RGBA').resize((141,68),Image.LANCZOS);im.save(ICONS+name+'.png');os.remove(ICONS+name+'_big.png')
P={
 'counter_straight':lambda:seg(0,0,'straight'),'counter_end_l':lambda:seg(0,0,'end_l'),'counter_end_r':lambda:seg(0,0,'end_r'),
 'counter_register':lambda:(seg(0,0,'register'),register(0,0)),'counter_corner':lambda:corner(0,0),
 'display_case':lambda:deli_case(0,0,2),'safe':lambda:safe(0,0),'shelf_goods':lambda:shelf_unit(0,0),'file_cabinet':lambda:file_cabinet(0,0),
 'desk_lamp':lambda:desk_lamp(0,0),'wastebin':lambda:wastebin(0,0),
 'plant_fern':lambda:fern_plant(0,0),'plant_ficus':lambda:ficus(0,0),'plant_bigleaf':lambda:big_leaf_plant(0,0),
 'armchair':lambda:armchair(0,0,(0.2,0.55,0.75)),'sofa_two':lambda:sofa2(0,0,(0.85,0.3,0.25)),'coffee_table_round':lambda:coffee_table(0,0),
 'chair_plain':lambda:chair(0,0,(0.9,0.7,0.15)),'stool_round':lambda:stool(0,0),'floor_lamp':lambda:floor_lamp(0,0),
 'bookcase_tall':lambda:tall_books(0,0),'rug_round':lambda:rug(0,0),
 'picture_landscape':lambda:frame(0,0,0.3,0.3,0.24,art_sun),'picture_portrait':lambda:frame(0,0,0.3,0.18,0.26,art_portrait),'picture_stripes':lambda:frame(0,0,0.3,0.22,0.2,art_stripes),'wall_clock':lambda:clock(0,0,0.3)}
for k,f in P.items(): export(k,f)

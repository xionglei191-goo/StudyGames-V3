"""Fixed detail cameras for the same-light round-one / round-two comparison."""
import bpy,sys,argparse,runpy
from pathlib import Path
from mathutils import Vector
p=argparse.ArgumentParser();p.add_argument('--room');p.add_argument('--out');p.add_argument('--phase');a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
views={'island':((9,-29,17),(-3,-14.7,8.5),15.5),'school':((5,-23,20),(-14,2.8,2.8),23),'home_kitchen':((11,-8,11),(.3,3.8,1.7),13)}
pos,target,scale=views[a.room];data=bpy.data.cameras.new('REVIEW_Round2Detail');cam=bpy.data.objects.new(data.name,data);bpy.context.scene.collection.objects.link(cam);cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();data.type='ORTHO';data.ortho_scale=scale;bpy.context.scene.camera=cam
sys.argv=['blender','--','--out',a.out,'--render','--width','1400','--samples','48','--filename',a.phase+'-detail.png']
runpy.run_path(str(Path(__file__).with_name('cloud_scene_inspect.py')),run_name='__main__')

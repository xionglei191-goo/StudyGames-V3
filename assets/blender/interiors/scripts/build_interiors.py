"""Explicit procedural rebuild. This NEVER runs as part of normal game refresh.

blender --background --factory-startup --python build_interiors.py -- --priority
blender --background --factory-startup --python build_interiors.py -- --all
Use --overwrite to intentionally replace an existing generated .blend.
"""
import sys, argparse, traceback, time
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import modeling, room_recipes, pipeline, align_to_plan

parser=argparse.ArgumentParser()
parser.add_argument('--all',action='store_true')
parser.add_argument('--priority',action='store_true')
parser.add_argument('--room',action='append')
parser.add_argument('--overwrite',action='store_true')
parser.add_argument('--resolution',type=int,default=1100)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
priority=['A','C','school','classroom','canteen','playground','home']
keys=list(room_recipes.NAMES) if args.all else priority if args.priority else [s.removeprefix('landmark_') for s in (args.room or [])]
if not keys:parser.error('Specify --all, --priority or --room room_id')
for key in keys:
    room_id='landmark_'+key if len(key)==1 else key
    file=pipeline.OUT/room_id/(room_id+'_v01.blend')
    if file.exists() and not args.overwrite:
        print('SKIP_EXISTING '+room_id,flush=True);continue
    print('ROOM_STARTED '+room_id,flush=True);start=time.time()
    if key=='A':
        import adapt_orchard
        adapt_orchard.build(args.resolution)
    else:
        modeling.setup(room_id)
        room_recipes.RECIPES[key]()
        align_to_plan.apply(key)
        pipeline.preview_setup(args.resolution)
    pipeline.finish_room(room_id,room_recipes.NAMES[key][0])
    print('ROOM_SECONDS '+room_id+' '+str(round(time.time()-start,1)),flush=True)


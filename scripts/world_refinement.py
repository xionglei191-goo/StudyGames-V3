"""Inventory, safeguard and synchronize the full-world refinement pass."""
from pathlib import Path
import argparse, hashlib, json, struct, shutil
from collections import Counter

ROOT = Path(__file__).resolve().parents[1]
PLAN = ROOT / 'docs/planning/world-refinement'
PROOF = ROOT / 'docs/verification/world-refinement'

def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

def glb_json(path):
    with path.open('rb') as stream:
        magic, version, size, length, kind = struct.unpack('<4sIIII', stream.read(20))
        assert magic == b'glTF' and version == 2 and size == path.stat().st_size
        assert kind == 0x4e4f534a
        return json.loads(stream.read(length))

def baseline():
    target = PLAN / 'baseline.json'
    if target.exists():
        raise SystemExit('Immutable baseline already exists; refusing to overwrite.')
    manifest = json.loads((ROOT/'assets/blender/interiors/interiors_manifest.json').read_text(encoding='utf-8-sig'))
    island = json.loads((ROOT/'assets/blender/alphabet_island/game_map_manifest.json').read_text(encoding='utf-8-sig'))
    rooms = [{'room_id':'village','name':'字母岛','blend':island['working_blend'].replace('\\','/'),
              'glb':'assets/blender/alphabet_island/alphabet_island_layout_v06_game.glb'}, *manifest['rooms']]
    files = {}
    inventory = []
    for room in rooms:
        for key in ('blend','glb','preview'):
            if room.get(key) and (ROOT/room[key]).exists():
                files[room[key]] = digest(ROOT/room[key])
        data = glb_json(ROOT/room['glb'])
        meshes = {i:m for i,m in enumerate(data.get('meshes',[]))}
        inventory.append({'room_id':room['room_id'], 'name':room['name'], 'blend':room['blend'], 'glb':room['glb'],
            'bytes':(ROOT/room['glb']).stat().st_size,
            'materials':[{'name':m.get('name',''), 'color':m.get('pbrMetallicRoughness',{}).get('baseColorFactor'),
                          'textured':'baseColorTexture' in m.get('pbrMetallicRoughness',{})} for m in data.get('materials',[])],
            'nodes':[{'name':n.get('name',''), 'mesh':n.get('mesh'), 'translation':n.get('translation'),
                      'materials':[p.get('material') for p in meshes.get(n.get('mesh'),{}).get('primitives',[])]}
                     for n in data.get('nodes',[]) if not n.get('name','').startswith(('SG_','PREVIEW_'))]})
    write(PLAN/'interiors-before.json', manifest)
    write(PLAN/'island-before.json', island)
    write(PLAN/'inventory.json', inventory)
    write(target, {'schema_version':1,'scope':44,'protected_files':files,'rooms':rooms})
    print(json.dumps({'rooms':len(rooms),'protected_source_files':len(files),'baseline':str(target)},ensure_ascii=False))

def verify_originals():
    base = json.loads((PLAN/'baseline.json').read_text(encoding='utf-8'))
    changed = [f for f,h in base['protected_files'].items() if not (ROOT/f).is_file() or digest(ROOT/f)!=h]
    if changed: raise SystemExit('Protected original changed: '+str(changed))
    print(json.dumps({'original_sources_unchanged':len(base['protected_files'])}))

def integrate():
    verify_originals()
    path=ROOT/'assets/blender/interiors/interiors_manifest.json'
    manifest=json.loads(path.read_text(encoding='utf-8-sig'))
    count=0
    for index,entry in enumerate(manifest['rooms']):
        candidates=list((ROOT/'assets/blender/interiors'/entry['room_id']).glob('*v*.manifest-entry.json'))
        candidates=[f for f in candidates if json.loads(f.read_text(encoding='utf-8')).get('refinement_revision')=='world-refinement-v1']
        if not candidates: continue
        assert len(candidates)==1,(entry['room_id'],candidates)
        refined=json.loads(candidates[0].read_text(encoding='utf-8'))
        assert digest(ROOT/refined['glb'])==refined['glb_sha256']
        manifest['rooms'][index]=refined;count+=1
    write(path,manifest)
    island_report=ROOT/'assets/blender/alphabet_island/validation_v07.json'
    if island_report.exists():
        audit=json.loads(island_report.read_text(encoding='utf-8'))
        assert digest(ROOT/audit['glb'])==audit['sha256'] and digest(ROOT/audit['blend'])==audit['blend_sha256']
        old=json.loads((PLAN/'island-before.json').read_text(encoding='utf-8'))
        data=glb_json(ROOT/audit['glb'])
        collision_by_node={n['name']:n.get('extras',{}).get('sg_collision','none') for n in data['nodes'] if 'mesh' in n}
        for name,kind in old['collision_by_node'].items():
            assert collision_by_node.get(name)==kind,('island collision metadata changed',name,kind)
        updated={**old,'version':7,'working_blend':audit['blend'],'working_blend_sha256':audit['blend_sha256'],
            'glb_sha256':audit['sha256'],'glb_bytes':audit['glb_bytes'],'refinement_revision':'world-refinement-v1',
            'source_v06_sha256':old['working_blend_sha256'],'source_v06_glb_sha256':old['glb_sha256'],
            'collision_by_node':collision_by_node,'collision_counts':dict(Counter(collision_by_node.values()))}
        write(ROOT/'assets/blender/alphabet_island/game_map_manifest.json',updated)
    print(json.dumps({'integrated_room_sources':count}))

if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['baseline','verify-originals','integrate'])
    args=parser.parse_args()
    {'baseline':baseline,'verify-originals':verify_originals,'integrate':integrate}[args.action]()

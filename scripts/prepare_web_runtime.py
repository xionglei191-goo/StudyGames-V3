"""Expose a completion-aware IDBFS flush in the inspected Godot 4.7 web glue.

The web game pauses before this call and navigates only after success. The exact
anchor is checked so a template update cannot silently disable save persistence.
"""
import hashlib
import json
import re
from pathlib import Path

RUNTIME = Path(__file__).resolve().parents[1] / 'build/web-online/index.js'
ANCHOR = 'Module["copyToFS"]=GodotFS.copy_to_fs;'
ADAPTER = r'''
/* ALPHABET_PROFILE_PERSISTENCE_BEGIN */
const alphabetIslandOriginalSync=GodotFS.sync;
let alphabetIslandPendingSync=null;
GodotFS.sync=function(){
  if(alphabetIslandPendingSync) return alphabetIslandPendingSync;
  alphabetIslandPendingSync=alphabetIslandOriginalSync.call(GodotFS).finally(()=>{
    alphabetIslandPendingSync=null;
  });
  return alphabetIslandPendingSync;
};
Module["flushPersistentFiles"]=async function(){
  const deadline=Date.now()+15000;
  while(GodotFS._syncing){
    if(Date.now()>deadline) throw new Error("Browser save is still busy");
    await new Promise(resolve=>setTimeout(resolve,10));
  }
  if(!GodotFS._idbfs) throw new Error("Browser persistence is unavailable");
  const error=await GodotFS.sync();
  if(error) throw error;
  return true;
};
/* ALPHABET_PROFILE_PERSISTENCE_END */
'''

def stamp_assets():
    report_path = RUNTIME.parent / 'build-info.json'
    report = json.loads(report_path.read_text('utf-8'))
    report['web_scripts_sha256'] = {
        name: hashlib.sha256((RUNTIME.parent / name).read_bytes()).hexdigest()
        for name in ['index.js', 'lobby.js', 'lobby.css', 'shared_save.js']
    }
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    page = RUNTIME.parent / 'index.html'
    html, count = re.subn(r'((?:src|href)=")(index\.js|lobby\.js|lobby\.css|shared_save\.js)(?:\?v=[0-9a-f]{12})?("|\')',
                         lambda match: match[1] + match[2] + '?v=' + report['web_scripts_sha256'][match[2]][:12] + match[3],
                         page.read_text('utf-8'))
    if count != 4:
        raise RuntimeError('Expected all four web shell asset references')
    page.write_text(html, encoding='utf-8')

def main():
    source = RUNTIME.read_text('utf-8')
    if source.count(ANCHOR) != 1 or 'flushPersistentFiles' in source:
        raise RuntimeError('Unexpected web template; inspect its IDBFS implementation first')
    RUNTIME.write_text(source.replace(ANCHOR, ANCHOR + ADAPTER), encoding='utf-8')
    stamp_assets()
    print('Web profile persistence adapter installed (one verified anchor).')

if __name__ == '__main__':
    main()

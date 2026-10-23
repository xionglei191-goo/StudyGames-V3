"""Independent read-only semantic spot audit; writes candidates, never changes registry.

This is an evidence filter, not a claim that substring rules solve full language grounding.
"""
from __future__ import annotations
from collections import Counter
import hashlib
import json
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[1]
REGISTRY=ROOT/'game/data/learning/story_prop_art.json'
OUT=ROOT/'docs/verification/art-finish-v3/story-semantic-review.json'
# Concrete entities actually named by the authored actions. Match only currently
# abstract steps: existing pending/missing labels already disclose their art gap.
NOUNS={
    'seashell':'贝壳','flowerpot':'花盆|泥盆','seed':'种子','thermometer':'温度计',
    'glass':'玻璃杯','tablecloth':'桌布','towel':'毛巾','envelope':'信封',
    'blocks':'积木','sofa':'沙发','hourglass':'沙漏','balloon':'气球',
    'blackboard':'黑板|粉笔|板擦','cola':'可乐','grass_patch':'草尖|草叶|草地|绿地',
    'wall_section':'墙面|墙脚|墙的高度','bookshelf':'书架','mirror':'镜子',
    'staircase':'楼梯','feather':'羽毛','toy_car':'玩具车','paper_cup':'纸杯',
    'mask':'面具','garland':'花环','wheel':'车轮','balance_scale':'秤',
    'toothbrush':'牙刷','paint_brush':'刷柄|刷毛','juice_glass':'果汁杯|搅匀果汁',
}


def main():
    registry=json.loads(REGISTRY.read_text(encoding='utf-8'));errors=[];candidates=[];main_flags=[]
    exact={
      'pen':({'pen'},'Steel/fountain pen must not use pencil art.'),
      'TV':({'television'},'A television is a distinct object from a desktop computer.'),
      'turkey':({'turkey'},'A turkey must not use a chicken image.'),
      'ping-pong':({'pingpong'},'A table-tennis ball/paddle must not use a soccer ball.'),
    }
    for sid,story in registry['stories'].items():
        word=story['word'];main=story['main_prop_id'];meaning=story['meaning_zh']
        if word in exact and main and main not in exact[word][0]:
            errors.append({'story_id':sid,'word':word,'kind':'wrong_main_object','actual':main,'expected':sorted(exact[word][0]),'reason':exact[word][1]})
        if word=='pot' and ('罐' in meaning or '瓶' in meaning) and main=='pot':
            main_flags.append({'story_id':sid,'word':word,'meaning':meaning,'actual':main,'reason':'Check asset: current production pot prompt is a cooking pan, while this curriculum sense is a storage jar.'})
        if word=='watch' and '手表' in meaning and main=='clock':
            main_flags.append({'story_id':sid,'word':word,'meaning':meaning,'actual':main,'reason':'Check wristwatch vs tabletop clock; authored steps assemble a watch strap.'})
        for vocabulary,asset,reason in [
            ('ship','boat','Curriculum says large powered ship; reused v2 B asset is explicitly a small wooden sailboat.'),
            ('underground','train','Curriculum says subway; reused v2 T asset is explicitly a toy steam locomotive.'),
            ('lion dance','lion','Authored actions use a lion head and fabric dance costume; current lion prompt is an ordinary four-legged animal.'),
        ]:
            if word==vocabulary and main==asset:main_flags.append({'story_id':sid,'word':word,'meaning':meaning,'actual':main,'reason':reason})
        if word=='face' and ('面对' in meaning or '面向' in meaning) and main=='anatomy_model':
            errors.append({'story_id':sid,'word':word,'kind':'polysemy_wrong_main','meaning':meaning,'actual':main,'expected':'no_main_for_verb_face','reason':'Verb face means turn toward; its continuity must not invent an anatomical model.'})
        for step in story['steps']:
            action=step['source_action'];pid=step['prop_id'];status=step['status']
            row={'story_id':sid,'word':word,'position':step['position'],'source_action':action,'actual_prop':pid,'status':status,'match':step['match']}
            if pid=='dragon' and '水龙头' in action:errors.append({**row,'kind':'substring_collision','expected':'tap','reason':'龙头 is part of 水龙头; there is no dragon.'})
            if pid=='clock' and re.search(r'手表[示达明]',action):errors.append({**row,'kind':'substring_collision','expected':'actor_action_or_previous_prop','reason':'The matching 手表 crosses 摆手 + 表示.'})
            if pid=='sweater' and step['match']=='袖子' and word!='sweater':errors.append({**row,'kind':'ambiguous_clothing_part','expected':'retain_explicit_clothing_or_actor_action','reason':'A sleeve does not identify a sweater; coat/myself scenes use different context.'})
            if pid=='anatomy_model' and re.search(r'手指[出向着]',action):errors.append({**row,'kind':'substring_collision','expected':'actor_action_or_main_prop','reason':'手指 can be part of 用手 + 指出; no anatomical model is named.'})
            if pid=='football' and step['match'] in ('把球','小球','球从','球稳','球滑','球推','球弹','球抛') and re.search(r'把球队|小球队',action):
                errors.append({**row,'kind':'substring_collision','expected':'team_emblem_or_named_object','reason':'球队 means team; the 把球 match crosses a complete noun boundary.'})
            if word=='brush' and pid=='paint_palette' and step['match'] in ('刷子','画笔'):
                errors.append({**row,'kind':'wrong_main_object','expected':'paint_brush','reason':'A handheld brush is distinct from a paint palette.'})
            if word in ('science','music','art') and step['match']=='exact_object_story_continuity' and pid:
                errors.append({**row,'kind':'abstract_main_mapped_to_arbitrary_object','expected':'explicit_action_object','reason':'Subject/activity name does not prove a flask, xylophone or palette exists in this action.'})
            if status=='abstract_runtime_text':
                matched=[key for key,pattern in NOUNS.items() if re.search(pattern,action)]
                if matched:candidates.append({**row,'candidate_entities':matched,'reason':'Action explicitly names a physical object; review whether it needs art or deliberate scene/background treatment.'})
    report={'registry_sha256':hashlib.sha256(REGISTRY.read_bytes()).hexdigest(),
            'scope':'curated false-positive checks and explicit noun screening on abstract actions; not exhaustive natural-language validation',
            'summary':{'stories':len(registry['stories']),'confirmed_rule_issues':len(errors),'ambiguous_asset_sense_reviews':len(main_flags),'abstract_concrete_candidates':len(candidates),
                       'step_statuses':dict(Counter(s['status'] for v in registry['stories'].values() for s in v['steps']))},
            'rule_issues':errors,'sense_reviews':main_flags,'abstract_concrete_candidates':candidates,
            'limits':['Props are selected from action semantics, not only word class. An abstract vocabulary word may still manipulate a concrete entity.',
                      'Background furniture or weather can be rendered as deliberate scene art; it must not silently be labeled abstract completion.',
                      'The report is a snapshot; rerun after registry rebuild to distinguish fixed issues from stale evidence.']}
    OUT.parent.mkdir(parents=True,exist_ok=True);OUT.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(report['summary'],ensure_ascii=False))


if __name__=='__main__':main()

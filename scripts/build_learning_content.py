"""Package reviewed-source vocabulary drafts for offline browsing, without editing plans.

Only reads repository planning inputs and already bundled audio. No network, external
textbook path, audio synthesis, or Godot import is required. --verify-only checks bytes.
"""
from __future__ import annotations
import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'game/data/learning'

def read(relative):
    return json.loads((ROOT / relative).read_text(encoding='utf-8-sig'))

def sha(relative):
    return hashlib.sha256((ROOT / relative).read_bytes()).hexdigest()

def clean(value):
    if isinstance(value, dict):
        return {k: clean(v) for k, v in value.items() if k not in {
            'image_absolute', 'manifest_path', 'source_manifest', 'source_snapshot',
            'runtime_static_basis', 'ownership', 'answer_chain_for_evaluator_only',
        }}
    if isinstance(value, list):
        return [clean(v) for v in value]
    if isinstance(value, str) and re.match(r'^[A-Za-z]:[\\/]', value):
        return None
    return value

def icon_shapes():
    # Original simple vector silhouettes. English/Chinese labels are separate real text.
    return {
        'A':'<path fill="#cc715a" d="M80 45C40 20 18 69 41 112Q59 143 80 125Q106 143 123 109C144 69 121 21 80 45Z"/><path d="M80 48Q76 29 87 17"/><path fill="#6b9265" d="M84 29Q113 6 123 22Q107 43 84 29Z"/>',
        'B':'<path fill="#b88a5d" d="M23 97H139L121 125H44Z"/><path d="M80 25V97"/><path fill="#f4d686" d="M73 29L30 86H73Z"/><path fill="#8cb5bc" d="M87 40L128 88H87Z"/><path stroke="#85b2bd" d="M18 137Q35 127 50 137T80 137T110 137T140 137"/>',
        'C':'<path fill="#e9c393" d="M30 75H132V127H30Z"/><path fill="#faf1d7" d="M30 71Q49 52 80 57Q113 53 132 71V87Q121 101 109 87Q95 104 81 88Q65 103 52 89Q39 101 30 87Z"/><path d="M81 57V36"/><path fill="#dfa753" d="M80 14Q99 33 80 38Q63 33 80 14Z"/>',
        'D':'<ellipse fill="#edc580" cx="80" cy="55" rx="49" ry="21"/><path fill="#bd705c" d="M31 55V113Q80 143 129 113V55Q80 84 31 55Z"/><path stroke="#f5e4b9" d="M34 64L56 124L80 77L104 124L127 64"/><path d="M23 18L72 45M139 18L92 45"/>',
        'E':'<path fill="#fff1cb" d="M80 19C53 19 25 71 33 106C41 146 122 146 129 106C137 71 107 19 80 19Z"/><path stroke="#d4b47d" d="M34 93L48 85L61 95L75 85L88 95L102 85L125 94"/>',
        'F':'<path stroke="#75956b" d="M80 144V72"/><path fill="#7eaa7c" d="M79 116Q37 111 42 92Q73 89 79 116M82 132Q122 129 122 108Q92 103 82 132"/><g fill="#d88977"><circle cx="80" cy="31" r="23"/><circle cx="110" cy="56" r="23"/><circle cx="97" cy="89" r="23"/><circle cx="60" cy="89" r="23"/><circle cx="48" cy="54" r="23"/></g><circle fill="#f0d086" cx="80" cy="61" r="23"/>',
        'G':'<circle fill="#98bbc0" cx="78" cy="69" r="47"/><path fill="#7d9b72" d="M40 45L62 29L76 45L67 65L84 79L74 103L55 91L52 68Z M99 33L118 50L113 75L92 70L88 49Z"/><path d="M121 17Q157 77 115 114Q94 134 62 124M91 123V140M61 141H120"/>',
        'H':'<ellipse fill="#b88660" cx="80" cy="113" rx="65" ry="21"/><path fill="#cfab75" d="M43 107L51 40Q80 26 109 40L117 107Q80 123 43 107Z"/><path fill="#6f947c" d="M46 86Q80 101 114 86L117 105Q80 121 43 105Z"/>',
        'I':'<path fill="#cf9f6e" d="M43 76H116L80 145Z"/><path stroke="#f2d7ad" d="M53 91L93 121M65 80L103 105M104 88L65 119M89 81L58 105"/><path fill="#e3b4a5" d="M39 76C28 36 64 27 79 41C92 13 133 44 122 76Z"/>',
        'J':'<path fill="#b3ccba" d="M45 40H115V54Q131 65 128 88V124Q128 140 111 140H49Q32 140 32 124V88Q29 65 45 54Z"/><rect fill="#b58f65" x="42" y="23" width="77" height="24" rx="6"/><rect fill="#faf0d4" x="50" y="76" width="60" height="42" rx="8"/>',
        'K':'<path fill="#e0b364" d="M80 15L131 68L80 119L29 68Z"/><path fill="#94b8b8" d="M80 15V119L29 68Z"/><path d="M80 15V119M29 68H131M80 119Q101 134 85 146"/><path fill="#c97b66" d="M83 129L68 124L71 141Z"/>',
        'L':'<path d="M68 24Q80 6 92 24M80 130V151"/><rect fill="#9f7c55" x="49" y="24" width="63" height="14" rx="4"/><path fill="#d99463" d="M49 38Q17 81 49 126H112Q144 81 112 38Z"/><path stroke="#f6dd95" d="M68 39Q52 82 68 124M91 39Q107 82 91 124"/><rect fill="#9f7c55" x="49" y="126" width="63" height="10" rx="3"/>',
        'M':'<path fill="#e7d5b0" d="M61 76H99L110 139H50Z"/><path fill="#c67a63" d="M20 82C22 12 138 12 140 82Q81 101 20 82Z"/><g fill="#f6dfb5"><circle cx="51" cy="59" r="10"/><circle cx="88" cy="42" r="11"/><circle cx="113" cy="72" r="9"/></g>',
        'N':'<ellipse fill="#b69b74" cx="80" cy="102" rx="63" ry="31"/><ellipse fill="#806c50" cx="80" cy="91" rx="52" ry="20"/><ellipse fill="#efe3c4" cx="61" cy="77" rx="17" ry="25"/><ellipse fill="#faf0cf" cx="98" cy="79" rx="18" ry="26"/><path stroke="#dec59a" d="M20 98L129 120M28 119L139 99M35 130L130 108M22 109L114 132"/>',
        'O':'<path fill="#a88b69" d="M39 40L33 18L62 33Q80 25 99 33L126 18L121 43Q140 69 128 115Q80 155 31 115Q18 70 39 40Z"/><path fill="#d5bc93" d="M45 98Q80 73 115 98V118Q81 142 45 118Z"/><g fill="#fbefd2"><circle cx="55" cy="65" r="24"/><circle cx="104" cy="65" r="24"/></g><g fill="#44554a"><circle cx="58" cy="65" r="8"/><circle cx="101" cy="65" r="8"/></g><path fill="#d4a759" d="M71 83H89L80 99Z"/>',
        'P':'<path d="M78 38Q74 17 90 13"/><ellipse fill="#cf8a50" cx="80" cy="88" rx="61" ry="46"/><ellipse fill="#e6a859" cx="80" cy="88" rx="41" ry="46"/><ellipse fill="#eab25f" cx="80" cy="88" rx="18" ry="46"/>',
        'Q':'<rect fill="#e3c89b" x="25" y="23" width="110" height="116" rx="9"/><path fill="#91afa0" d="M29 27H63V62H29Z M98 27H131V62H98Z M64 63H98V99H64Z M29 100H63V135H29Z M98 100H131V135H98Z"/><path fill="#c88a78" d="M64 27H98V62H64Z M29 63H63V99H29Z M98 63H131V99H98Z M64 100H98V135H64Z"/><path stroke="#f8ecd1" d="M63 25V138M98 25V138M27 62H133M27 99H133"/>',
        'R':'<path d="M80 23V12M36 82H20V111M124 82H141V111M61 122V144M100 122V144"/><circle fill="#d58a6b" cx="80" cy="11" r="7"/><rect fill="#9cb8b1" x="37" y="28" width="88" height="53" rx="12"/><rect fill="#a8c3bb" x="42" y="84" width="77" height="44" rx="7"/><g fill="#415f53"><circle cx="61" cy="53" r="8"/><circle cx="101" cy="53" r="8"/></g><path d="M66 68H96"/><circle fill="#dfad65" cx="80" cy="105" r="10"/>',
        'S':'<path fill="#e8bc61" d="M80 12L100 55L147 61L113 95L122 143L80 120L38 143L47 95L13 61L60 55Z"/>',
        'T':'<path fill="#91b2b4" d="M21 75H98V121H21Z"/><path fill="#ce9172" d="M89 38H135V121H89Z"/><path fill="#f3dfb0" d="M101 49H124V75H101Z"/><path fill="#9b8062" d="M29 50H47V75H29Z"/><path d="M18 126H141"/><g fill="#577268"><circle cx="42" cy="126" r="14"/><circle cx="78" cy="126" r="14"/><circle cx="119" cy="126" r="14"/></g><path stroke="#c2cbc0" d="M37 40Q20 28 38 17"/>',
        'U':'<path fill="#87afb6" d="M14 78Q80 -16 146 78Q123 61 102 79Q80 61 58 79Q36 61 14 78Z"/><path d="M80 19V130Q80 151 99 141Q108 138 105 126M80 19Q55 40 58 79M80 19Q105 40 102 79"/>',
        'V':'<path fill="#9c9f85" d="M14 139L65 45H99L146 139Z"/><path fill="#d58b64" d="M65 45H99L113 76L98 68L83 82L68 69L51 72Z"/><path stroke="#d7b090" d="M68 32Q52 16 70 11M87 29Q103 16 88 7M105 34Q125 28 116 16"/>',
        'W':'<path fill="#8bb1bc" d="M24 99C17 48 74 31 105 68Q113 77 117 90L136 76L149 81L140 106Q121 134 75 134Q37 134 24 99Z"/><path fill="#c3d7cd" d="M30 107Q70 130 115 109Q103 137 68 131Q40 129 30 107Z"/><circle fill="#40564e" cx="49" cy="83" r="5"/><path stroke="#93bec6" d="M66 53V24M66 34Q49 14 39 24M66 33Q82 12 94 26"/>',
        'X':'<path d="M29 132L131 31M21 33L58 67M119 98L146 125"/><g stroke="#596f60"><path fill="#be7c67" d="M29 103L49 83L76 110L56 130Z"/><path fill="#d9aa62" d="M49 82L68 63L97 92L78 111Z"/><path fill="#92b39c" d="M68 62L87 43L117 73L98 92Z"/><path fill="#8fb2bd" d="M87 42L106 23L137 54L118 73Z"/></g><circle fill="#dbb878" cx="19" cy="31" r="10"/><circle fill="#dbb878" cx="146" cy="127" r="10"/>',
        'Y':'<circle fill="#ca9a9b" cx="76" cy="75" r="49"/><path stroke="#f1d7cb" d="M38 45Q55 95 113 108M29 65Q63 112 100 120M53 30Q58 75 122 91M84 27Q48 66 38 104M104 38Q70 73 58 121M119 59Q91 91 81 125"/><path stroke="#ca9a9b" d="M113 107Q153 104 143 137Q132 151 116 142"/>',
        'Z':'<path fill="#f0ebd8" d="M41 53H107L125 31L141 44L124 76L113 91L112 137H99V99H59V137H46V93L33 82Z"/><path fill="#59675f" d="M44 52H55L61 96H50Z M67 53H78L82 99H71Z M92 54H103L103 98H92Z M112 43L122 34L132 57L124 70Z"/><path d="M34 63L18 89M125 31L121 18M135 37L145 27"/><circle fill="#354b42" cx="133" cy="47" r="3"/>',
    }

def svg_document(shapes):
    return '<svg xmlns="http://www.w3.org/2000/svg" width="160" height="160" viewBox="0 0 160 160"><g stroke="#546b58" stroke-width="3.3" stroke-linecap="round" stroke-linejoin="round" fill="none">'+shapes+'</g></svg>\n'

def build():
    catalog = read('docs/planning/vocabulary/data/catalog.json')
    adapter = read('docs/planning/vocabulary/data/mainline_entries.json')
    contract = read('docs/planning/vocabulary/data/integration_contract.json')
    curriculum = read('game/data/curriculum.json')
    sources = {s['id']: clean(s) for s in catalog['sources']}
    original_stories = {s['id']: s for s in catalog['stories']}
    entries, lexemes, stories = [], {}, {}
    phrases = curriculum['phrases'].values() if isinstance(curriculum['phrases'], dict) else curriculum['phrases']
    audio_by_text = {}
    for phrase in phrases:
        audio = phrase.get('audio', '')
        if audio.startswith('res://') and (ROOT/'game'/audio.removeprefix('res://')).is_file():
            audio_by_text[phrase['en']] = {'path': audio, 'text': phrase['en'], 'kind':phrase.get('audio_kind'),
                'source':clean(phrase.get('source',{})), 'review_status':'bundled_candidate_not_new_listening_assessment',
                'listening_pass_available':False}
    for item in adapter['entries']:
        entry = {k: deepcopy(item[k]) for k in ['entry_id','lexeme_id','sense_id','story_id','source_unit',
            'spelling_display','meaning_zh','kind','requirement','task_permissions','source_ids','review_status']}
        entry['audio'] = audio_by_text.get(item['spelling_display'], {})
        entry['supplemental_beats'] = clean(item['supplemental_beats'])
        entries.append(entry)
        lexemes.setdefault(item['lexeme_id'], {k:deepcopy(item[k]) for k in ['letter_slots','boundaries','reconstruction_tokens']})
        story = original_stories[item['story_id']]
        stories.setdefault(item['story_id'], {**{k:clean(item[k]) for k in ['story_beats','memory_home','guidance','orthography_events']},
            'meaning_anchor':story['meaning_anchor'], 'steps':story['steps'],'transfer_task':story['transfer_task']})
    books = [{k:b[k] for k in ['book_id','title','grade','volume','edition','manifest_sha256','unit_count']} for b in catalog['books']]
    codebook = deepcopy(contract['codebook'])
    for symbol in codebook:
        symbol['icon_path'] = 'res://data/learning/icons/%s.svg' % symbol['letter']
        # Keep original vectors inside JSON too: exported PCKs may omit raw SVG
        # source after import; the runtime must not depend on editor-only files.
        symbol['svg_source'] = svg_document(icon_shapes()[symbol['letter']])
    bundle = {'schema_version':'learning-content-v1','content_revision':adapter['content_revision'],
        'codebook_revision':adapter['codebook_revision'],'books':books,'entries':entries,'lexemes':lexemes,'stories':stories,
        'unit_index':adapter['unit_index'],'codebook':codebook,'sources':sources,
        'content_status':{'human_editor_review':'pending','child_trial':'not_conducted','learning_effect':'not_validated',
          'parent_note':'八册词表来源已经核对；记忆故事仍待独立编辑复核。当前提供可选浏览和练习，不代表正式教材验收或学习效果。'},
        'source_hashes':{x:sha(x) for x in ['docs/planning/vocabulary/data/mainline_entries.json','docs/planning/vocabulary/data/catalog.json']}}
    prologue = clean(read('docs/planning/mainline/alphabet_prologue.json'))
    prologue = {k:prologue[k] for k in ['schema_version','id','title','navigation','districts','letters','opening','completion_contract','common_experience']}
    prologue['content_revision'] = adapter['content_revision']
    prologue['codebook_revision'] = adapter['codebook_revision']
    arcs = clean(read('docs/planning/mainline/curriculum_arcs.json'))
    arcs = {k:arcs[k] for k in ['schema_version','title','coverage','books','units','progression_policy']}
    arcs['implementation_scope'] = 'chapter_catalog_and_vocabulary_join; authored_events_require_individual_runtime_implementation'
    outputs = {'catalog.json':json.dumps(bundle,ensure_ascii=False,separators=(',',':'))+'\n',
               'prologue.json':json.dumps(prologue,ensure_ascii=False,indent=2)+'\n',
               'curriculum_arcs.json':json.dumps(arcs,ensure_ascii=False,indent=2)+'\n'}
    for letter, shapes in icon_shapes().items():
        outputs['icons/'+letter+'.svg'] = svg_document(shapes)
    assert len(entries)==1314 and len(books)==8 and len(codebook)==26
    for e in entries:
        assert ''.join(t['raw'] for t in lexemes[e['lexeme_id']]['reconstruction_tokens'])==e['spelling_display']
        assert [p for b in stories[e['story_id']]['story_beats'] for p in b['letter_positions']]==list(range(1,len(lexemes[e['lexeme_id']]['letter_slots'])+1))
    assert not re.search(r'"[A-Za-z]:[\\/]',outputs['catalog.json'])
    report={'status':'passed','schema_version':'learning-content-v1','entries':len(entries),'lexemes':len(lexemes),'stories':len(stories),
        'books':len(books),'units':len(adapter['unit_index']),'icons':len(icon_shapes()),'exact_bundled_audio_entries':sum(bool(e['audio']) for e in entries),
        'content_revision':adapter['content_revision'],'codebook_revision':adapter['codebook_revision'],
        'files':{k:{'bytes':len(v.encode()),'sha256':hashlib.sha256(v.encode()).hexdigest()} for k,v in outputs.items()},
        'runtime_requires_source_library':False,'human_editor_review':'pending','child_trial':'not_conducted'}
    outputs['build_report.json']=json.dumps(report,ensure_ascii=False,indent=2)+'\n'
    return outputs,report

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--verify-only',action='store_true')
    args=parser.parse_args()
    outputs,report=build()
    for rel,value in outputs.items():
        path=OUT/rel
        if args.verify_only:
            assert path.read_bytes()==value.encode('utf-8'), 'outdated package: '+rel
        else:
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes(value.encode('utf-8'))
    print(json.dumps({k:v for k,v in report.items() if k!='files'},ensure_ascii=False))

if __name__=='__main__':main()

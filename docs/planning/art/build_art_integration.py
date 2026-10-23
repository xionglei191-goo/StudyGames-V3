"""Build planning-only art interfaces from current authored sources.

Writes only files in this directory. Does not rewrite vocabulary stories,
source books, runtime data, Blender scenes, or game assets.
"""
from __future__ import annotations

import hashlib
import json
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
VOCAB_PATH = ROOT / "docs/planning/vocabulary/data/catalog.json"


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def save(name, data):
    (HERE / name).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def source(path):
    target = ROOT / path
    if not target.is_file():
        raise ValueError(f"Claimed source missing: {path}")
    return {"path": path, "status": "existing_verified", "sha256": hashlib.sha256(target.read_bytes()).hexdigest()}


def main():
    vocab = read(VOCAB_PATH)
    prologue = read(ROOT / "docs/planning/mainline/alphabet_prologue.json")
    rooms = {r["room_id"]: r for r in read(ROOT / "game/data/interiors_manifest.json")["rooms"]}
    stories = {r["id"]: r for r in vocab["stories"]}
    occurrences = {r["id"]: r for r in vocab["occurrences"]}
    lexemes = {r["spelling"]: r for r in vocab["lexemes"]}
    integration = read(ROOT / "docs/planning/vocabulary/data/integration_contract.json")
    adapted = read(ROOT / "docs/planning/vocabulary/data/mainline_entries.json")
    adapted_entries = {r["entry_id"]: r for r in adapted["entries"]}
    codebook = {r["letter"]: r for r in integration["codebook"]}
    miniature_assets = []
    for entry in prologue["letters"]:
        letter = entry["letter"]["uppercase"]
        anchor = entry["anchor"]
        room = rooms[entry["scene_ref"]["room_id"]]
        assert vocab["landmarks"][letter]["anchor_en"] == anchor["canonical_word"]
        miniature_assets.append({
            "id": f"mnemonic_anchor_{letter}", "letter": letter,
            "codebook_asset_identity": codebook[letter]["asset_identity"],
            "canonical_anchor_en": anchor["canonical_word"],
            "representative_label_zh": anchor.get("representative_label_zh", anchor["chinese_image_name"]),
            "canonical_word_zh": anchor.get("canonical_word_zh", anchor["chinese_image_name"]),
            "implementation_status": "planned", "priority": "P0", "production_stage": "P2",
            "scene_ids": ["home", "classroom", room["room_id"]],
            "prologue_entry_id": entry["id"], "landmark_room_id": room["room_id"],
            "source_candidates": [source(room["source_blend"]), source(room["source_glb"])],
            "proposed_asset_path": f"assets/mnemonic/anchors/{letter}/anchor_{letter}_v01.glb",
            "proposed_asset_status": "proposed_new_not_created",
            "representations": ["transparent_image_card", "lightweight_3d_prop", "static_reduced_motion_pose"],
            "visual_goal": entry["representative_reveal_cn"],
            "transform_policy": "Extract/copy a representative prop into a new source file; never move the public landmark or SG markers.",
            "definition_instance_key": "story_id + letter_position; occurrence is preserved for repeated letters",
            "runtime_instance_key": "invocation_id + story_id + letter_position; retain invocation_id on resume",
            "glyph_policy": "Render exact raw glyph and case from vocabulary tokens with a font, never from generated image text.",
            "audio_policy": "letter name, anchor word, whole target word and narration are separate reviewed tracks; never concatenate anchor audio to pronounce a word.",
            "acceptance": ["recognizable against its existing landmark at actual game camera size", "same letter always has same representative image", "repeated letter instances remain distinct and ordered", "reduced motion preserves order and meaning"],
        })
    egg = next(x for x in miniature_assets if x["letter"] == "E")
    egg["canonical_word_zh"] = "鸡蛋"
    egg["representative_label_zh"] = "蛋壳（完整蛋形）"
    egg["special_constraint"] = "主轮廓为完整椭圆蛋形；可开合展示内部，复位后仍完整；碎壳不能单独作为Egg词义图，也不改变E地标映射。"

    token_counts = Counter(t["type"] for lex in vocab["lexemes"] for t in lex["tokens"])
    symbol_specs = [
        ("space", "词间空位", "保留固定间距和分词边界，不占字母形象序号", "International Children's Day"),
        ("apostrophe", "撇号", "严格保留原始位置与字符；不要当作字母或重音", "I'm"),
        ("hyphen", "连字符", "显示真实短横，保留复合词边界；与漏字槽分开", "T-shirt"),
        ("sentence_punctuation", "句末标点", "保留句号/感叹号等原样；不朗读为地标", "Be careful!"),
        ("abbreviation_point", "缩写点", "跟随对应字母，区别句末标点和连续占位点", "p.m."),
        ("digit", "数字", "用原始数字字形，不把1或5改成英文拼写", "1st"),
        ("placeholder", "可替换内容占位", "保留完整...跨度及句式槽功能，不拆成三个缩写点", "from... to..."),
        ("diacritic", "字母附加符号", "是原字母的修饰层；é仍是一格E形象，显示é而非去掉重音", "café"),
    ]
    symbols = []
    for kind, label, rule, example in symbol_specs:
        symbols.append({"id": f"orthography_{kind}", "token_type": kind,
                        "label": label, "implementation_status": "planned", "priority": "P0",
                        "production_stage": "P2" if kind in {"space", "apostrophe"} else "P3",
                        "render_kind": "font_glyph_or_layout_primitive", "rule": rule,
                        "sample_lexeme_id": lexemes[example]["id"],
                        "observed_tokens": sum(bool(t.get("diacritic")) for x in vocab["lexemes"] for t in x["tokens"]) if kind == "diacritic" else token_counts[kind],
                        "source_candidates": [{"path": "docs/planning/vocabulary/data/catalog.json", "status": "existing_verified"}],
                        "proposed_asset_status": "proposed_component_not_created",
                        "acceptance": ["surface_position/raw/letter_position round-trip unchanged", "nonletters never increase letter_chain length", "exact text remains readable in reduced motion"]})

    stage_specs = [
        ("story_stage", "独立记忆舞台", "卡片、桌面或局部镜框；持有故事实例，公共世界地标不动"),
        ("ordered_slots", "顺序格与重复实例", "每个letter_position独立槽，重复形象复用资源但不合并实例"),
        ("frame_timeline", "分镜接续条", "按来源frames切分，支持逐步、回看、续看，分镜边界不重排字母"),
        ("meaning_context", "词义情境牌", "先提供词义和完整词音，人物/物体/事件图明确词义，不由编码物硬猜"),
        ("support_controls", "H0至H5支持控件", "共用故事，逐级增援；无提示、示范、跳过的证据分别记录"),
        ("storage_locator", "固定位置与相邻义项页", "按storage.root_location及lexeme_id/story_id定位；地点文字不冒充现有SG"),
        ("letter_reveal", "图像转回字母", "逐格显示原字形大小写，再恢复空格和标点，不改变目标拼写"),
        ("local_weather_context", "故事内天气语境", "雨/云/晴只在独立舞台按已审校故事播放，冻结环境不冻结必要教学示范"),
        ("neutral_colour_context", "标准色观察层", "颜色目标使用中性照明或标准色卡，不受全岛黄昏偏色干扰"),
        ("receipt_checkpoint", "演出恢复位置", "记住故事/分镜/步/已提交凭据；跳过和重看不重复发奖、不伪造听力"),
    ]
    components = [{"id": f"mnemonic_{key}", "label": label, "purpose": purpose,
                   "implementation_status": "planned", "production_stage": "P1" if key in {"story_stage", "ordered_slots", "frame_timeline", "support_controls", "receipt_checkpoint"} else "P2",
                   "clock_owner": "performance_clock", "proposed_asset_status": "proposed_component_not_created",
                   "acceptance": ["pause menu and background freeze playback", "restore retains exact source identity and sequence", "world collision/SG markers and task receipts unchanged"]}
                  for key, label, purpose in stage_specs]
    samples = []
    sample_words = ["nose", "hello", "book", "apple", "school", "football", "I'm", "T-shirt", "p.m.", "No.", "1st", "Be careful!", "from... to...", "café", "International Children's Day", "rain", "rainy", "cloudy", "sunny", "morning"]
    for word in sample_words:
        lex = lexemes[word]
        story = stories[lex["story_ids"][0]]
        source_occurrences = [occurrences[x] for x in lex["occurrence_ids"] if occurrences[x]["story_id"] == story["id"]]
        tokens = []
        for index, token in enumerate(lex["tokens"]):
            item = {"token_index": index, **token}
            item["asset_id"] = f"mnemonic_anchor_{token['letter']}" if token["type"] == "letter" else f"orthography_{token['type']}"
            item["instance_id"] = f"{story['id']}:letter:{token['letter_position']}" if token["type"] == "letter" else f"{story['id']}:surface:{token['surface_position']}"
            if token.get("diacritic"):
                item["modifier_asset_id"] = "orthography_diacritic"
            tokens.append(item)
        samples.append({"id": f"sample_{lex['id']}", "status": "planning_only", "spelling": word,
                        "entry_ids": [x["id"] for x in source_occurrences], "lexeme_id": lex["id"], "sense_id": story["id"], "story_id": story["id"],
                        "meaning_label": story["meaning_label"], "tokens": tokens,
                        "instance_scope": "definition_fixture; runtime prefixes invocation_id, and resumes retain it",
                        "letter_count": len(lex["letter_chain"]), "frame_count": len(story["frames"]),
                        "frames": story["frames"], "storage": story["storage"],
                        "curricular_requirements": [{"entry_id": x["id"], "requirement": x["requirement"]} for x in source_occurrences],
                        "entry_permissions": [{"entry_id": x["id"], "task_permissions": adapted_entries[x["id"]]["task_permissions"]} for x in source_occurrences],
                        "adapter_letter_slots": adapted_entries[source_occurrences[0]["id"]]["letter_slots"],
                        "adapter_memory_home": adapted_entries[source_occurrences[0]["id"]]["memory_home"],
                        "spelling_gate": "optional_recognition_scaffold_not_forced_spelling" if word == "International Children's Day" else "follow_occurrence_requirement_never_strengthen_by_art",
                        "source_status": "copied_structure_not_rewritten_story; human_editor_and_child_trial_pending"})
    contract_paths = ["docs/planning/vocabulary/data/integration_contract.json", "docs/planning/vocabulary/data/mainline_entries.json"]
    bridge_sources = [source(x) for x in contract_paths if (ROOT / x).is_file()]
    manifest = {
        "schema_version": 1, "status": "planning_only", "implementation_status": "not_implemented", "date": "2026-10-22",
        "authority": "Vocabulary owns spelling, token positions, senses, story steps, prompt text and curricular requirements. Art owns reusable representations and playback layout only.",
        "source_snapshot": [source("docs/planning/vocabulary/data/catalog.json"), source("docs/planning/mainline/alphabet_prologue.json"), source("game/data/interiors_manifest.json")],
        "integration_sources": bridge_sources,
        "content_revision": integration["content_revision"], "codebook_revision": integration["codebook_revision"],
        "source_counts": {k: len(vocab[k]) for k in ["books", "lexemes", "stories", "occurrences"]},
        "identity_contract": {"entry_id": "occurrence.id (occ-*)", "lexeme_id": "lexeme.id (lex-*)", "sense_id": "story.id (story-*)", "story_id": "same source story.id", "definition_letter_instance_id": "story_id + letter_position", "definition_nonletter_instance_id": "story_id + surface_position", "runtime_instance_id": "invocation_id + definition_instance_id; preserve invocation_id on resume"},
        "prompt_levels": [{"id": f"H{level}", "source_level": level, "name": name} for level, name in enumerate(["自主", "位置与意义", "第一步", "缺口接续", "逐步搭桥", "完整示范"])],
        "prompt_render_contract": {"H0": "hide story, image chain and answer hints until help is opened; actively opening them changes the observed assistance evidence", "H3": "missing letter and miniature stay hidden until reveal requested; answer_chain_for_evaluator_only is never UI text", "all_levels": "log actual shown hints/replays, not just selected level; H0 alone cannot prove independence", "audio_missing": "show pending/unavailable and permit visual assisted story; never synthesize listening evidence"},
        "storage_contract": {"root_location": "Display/content index copied from authored story; not a verified physical node", "storage_slot": "lexeme_id/story_id", "same_spelling_new_sense": "adjacent_story_page_same_root", "same_sense_reuse": "reuse_story_page_keep_occurrence_requirement_and_evidence_separate", "world_geometry_changes": False},
        "clock_contract": {"world_clock": "paused during dialogue/memory/teaching, pause menus and application background", "performance_clock": "necessary story actions and semantic weather may run during dialogue/memory; pause menu/background freeze it", "semantic_weather": "local reviewed stage preset or static context panel, never wait for random global weather", "user_preferences": "fixed daylight/clear weather and reduced motion retained; use readable local explanation/static keyframes when needed", "learning_time": "real evidence timestamps unchanged; no offline catch-up"},
        "miniature_assets": miniature_assets, "orthography_assets": symbols, "stage_components": components, "samples": samples,
        "pilot": {"stage": "P1", "cases": ["nose", "book", "I'm", "café", "International Children's Day", "rain"], "longest_case": {"spelling": "International Children's Day", "letters": 25, "frames": 7, "mandatory_spelling": False}, "acceptance": ["book's two O instances stay separate", "café keeps acute accent at surface position 4", "from... to... keeps multi-character placeholder spans", "25-letter sample can pause/resume across seven frames", "rain context remains clear with world decoration frozen", "no art event alone awards language mastery"]},
        "limits": ["Planning/static source checks only; no produced miniature models or playable renderer", "No source text or story rewrite", "No runtime, camera, motion quality, accessibility or child trial acceptance"]}
    save("mnemonic_story_assets.json", manifest)

    npc = read(HERE / "npc_animation_assets.json")
    capability_map = {
        "humanoid_core_v1": ["in_place_locomotion", "dialogue_gesture", "point", "paired_handoff", "stand_sit_transition"],
        "dino_special_v1": ["in_place_locomotion", "dialogue_gesture", "point", "paired_handoff"],
        "wheelchair_humanoid_v1": ["seated_contact", "dialogue_gesture", "point", "paired_handoff"],
    }
    for rig in npc["rig_families"]:
        rig["planned_capabilities"] = capability_map.get(rig["id"], ["story_key_pose_pending"])
        rig["capability_status"] = "planning_specification_requires_model_and_clip_validation"
    special_shapes = {
        "quadruped_dog_v1": ("犬类四足", "四足稳定接触地面，头颈自然，尾部保持该角色源图的中性轮廓", "在四足接触不变的前提下将头部朝向当前故事对象，保持嘴部与身体中性，不以抬前爪模仿人形挥手"),
        "quadruped_cat_v1": ("猫类四足", "四足或来源允许的坐伏支点稳定，尾部不穿身体与家具", "维持已核验支撑姿态，头部朝向故事对象；不强制站成人形，不自动添加抓挠或追逐"),
        "quadruped_elephant_v1": ("象类四足", "四足承重，象鼻自然垂放或按源图收拢，身体底部与地面不穿插", "保持四足承重，头/象鼻停在可读的注意姿态；象鼻不冒充已制作的人手交接"),
        "aquatic_fish_v1": ("水中鱼类", "在来源场景的水中保持自然体轴和鳍展开静态姿态，原点不漂出水域", "在水中以已确认的朝向表达注意，保持鳍尾完整轮廓；不落地、不播放腿部动作"),
        "primate_v1": ("灵长类", "依据已核验源图选择实际支撑姿态与尾部位置，不预设直立人形站姿", "在同一稳定支撑方式下朝向故事对象；仅在源图/分镜要求且另行验收后安排抓握"),
        "quadruped_rabbit_v1": ("教材四足兔", "四肢与身体按教材图像保持自然坐伏或四足接触，耳朵与尾部轮廓清楚", "保持原支撑姿态，头部和耳朵朝向故事焦点；与岛屿拟人兔兔的站立身体和服饰分开"),
        "quadruped_monster_v1": ("故事四足怪兽", "依Nian原图确定四肢支撑和角/尾位置，保持中性可读轮廓", "保持安全距离和已核验支撑，朝向故事焦点等待；不默认冲撞、追逐或突然扑向镜头"),
        "avian_v1": ("鸟类", "按来源安排双足栖息于已标注支点，翼收拢、爪部接触明确", "在同一栖息点朝向故事对象，保持翼和尾的清楚轮廓；不能因有翅膀默认飞行或跨岛移动"),
        "articulated_robot_v1": ("机械关节机器人", "依据Robbie源图确定底座/脚部接触，硬壳关节轴中性且无穿插", "保持支撑和已验证关节范围，头部/显示面朝向对象；指向、递物另做可达与接触规格"),
    }
    basic_specs, pose_specs = [], []
    for rig_id, (label, idle_pose, wait_pose) in special_shapes.items():
        spec_id = f"special_basic_{rig_id}"
        pose_ids = []
        for state_id, description in [("idle", idle_pose), ("event_wait", wait_pose)]:
            pose_id = f"pose_{rig_id}_{state_id}"
            pose_ids.append(pose_id)
            pose_specs.append({"id": pose_id, "rig_family_id": rig_id, "behavior_state_id": state_id,
                               "label": f"{label}：{'稳定待机' if state_id == 'idle' else '安全等待'}",
                               "implementation_status": "planned", "production_stage": "P3",
                               "representation": "static_key_pose", "specification": description,
                               "motion": "no cyclic motion and no root translation; fixed key pose is the minimum fallback",
                               "source_file": None, "source_file_status": "not_created",
                               "source_candidates": ["Blender自制骨架姿势；依据教材已核验形体与接触面"],
                               "external_source_rule": "若使用外部动作的定格，先记录来源/适用条款并通过该骨架和角色比例适配，不能当作已取得素材。",
                               "proposed_output": f"assets/characters/shared/{rig_id}/poses/{state_id}_v01.blend",
                               "acceptance": ["原教材形体与该角色比例已核验，不能由骨架族名猜外观", "支撑点/爪足/鳍/硬壳无穿插且实际镜头可读", "姓名、交互锚点和碰撞仍随同一角色实体", "暂停/恢复/减少动态保持同一姿态与逻辑事实", "不得把静态姿态计为已制作步态、飞行、游动或专有剧情动作"]})
        basic_specs.append({"id": spec_id, "rig_family_id": rig_id, "implementation_status": "planned",
                            "production_stage": "P3", "pose_spec_ids": pose_ids,
                            "required_behaviors": ["idle", "event_wait"], "offscreen_policy": "logic_only_no_pose_playback",
                            "scope": "最低可读姿态规格；模型、绑定和姿势均待制作，不等于完整章节演出已覆盖"})
    npc["special_rig_basic_specs"] = basic_specs
    npc["pose_specs"] = pose_specs
    special_work_orders = []
    clip_map = {r["id"]: r for r in npc["clips"]}
    behavior_map = {r["id"]: r for r in npc["behavior_states"]}
    for behavior in npc["behavior_states"]:
        if behavior["id"] == "escort":
            behavior["clip_ids"] = [x for x in behavior["clip_ids"] if x != "wheelchair_idle_relaxed"]
        behavior["required_capabilities"] = {"travel_to_anchor": ["in_place_locomotion"], "escort": ["in_place_locomotion"], "seated_work": ["stand_sit_transition"], "paired_handoff": ["paired_handoff"]}.get(behavior["id"], [])
        behavior["clip_selection_rule"] = "character allowlist AND rig-family compatibility AND required capabilities; no global clip fallback across rigs"
    rig_map = {r["id"]: r for r in npc["rig_families"]}
    for actor in npc["characters"]:
        rig = rig_map[actor["rig_family_id"]]
        bindings = []
        for state_id in actor.get("behavior_state_ids", []):
            state = behavior_map[state_id]
            clips = [x for x in state["clip_ids"] if x in actor.get("required_clip_ids", []) and rig["id"] in clip_map[x]["rig_family_ids"]]
            capabilities_ok = set(state["required_capabilities"]) <= set(rig["planned_capabilities"])
            pose_id = f"pose_{rig['id']}_{state_id}" if not clips and rig["id"] in special_shapes and state_id in {"idle", "event_wait"} else None
            bindings.append({"state_id": state_id, "candidate_clip_ids": clips,
                             "planned_spec_id": f"special_basic_{rig['id']}" if pose_id else None,
                             "pose_spec_id": pose_id,
                             "required_capabilities_satisfied_in_plan": capabilities_ok,
                             "status": "logic_only" if state_id == "offscreen" else "planned_compatible_candidates_not_tested" if clips and capabilities_ok else "planned_explicit_pose_fallback_not_tested" if pose_id and capabilities_ok else "awaiting_special_clip_specification",
                             "fallback": "explicit static key pose only; never substitute walking/standing or another rig's curves"})
        actor["behavior_clip_bindings"] = bindings
        if rig["id"] in special_shapes:
            work_id = f"special_actions_{actor['id']}"
            actor["special_action_work_order_id"] = work_id
            special_work_orders.append({"id": work_id, "character_id": actor["id"],
                                        "textbook_character_id": actor["textbook_character_id"], "rig_family_id": rig["id"],
                                        "implementation_status": "planned", "production_stage": "P3",
                                        "required_before": "this_character_corresponding_chapter_release",
                                        "source_refs_pointer": f"characters[id={actor['id']}].source_refs",
                                        "source_scene_refs": actor.get("mainline_refs", []),
                                        "basic_spec_id": f"special_basic_{rig['id']}",
                                        "pose_spec_ids": [f"pose_{rig['id']}_idle", f"pose_{rig['id']}_event_wait"],
                                        "required_action_semantics": actor.get("required_action_semantics_pending_special_clips", []),
                                        "source_action_breakdown_status": "pending_corresponding_source_scene_editorial_review",
                                        "source_action_breakdown_rule": "逐场景列出演员必须完成的动作、对象、起止姿态和接触事件；仅待机/等待不是完整演出。移动/飞行/游动仅当已审校原场景需要时增加，不能强行用人形曲线替代。",
                                        "deliverables": ["该角色已核验形体的可编辑模型与专用绑定", "两个最低姿态的角色比例与接触适配", "逐场景动作矩阵：动作语义、片段/姿态ID、道具/接触、暂停恢复与未决项", "按来源需要制作的移动或专有片段及素材来源记录", "实际游戏机位录像、输入中断/恢复与替换回退证据"],
                                        "acceptance": ["身份/来源/形体核验通过，外观待核时不提前批准模型", "本角色两项最低行为绑定均解析到本骨架pose并实际可读", "该章全部必要动作有明确规格与已验收表现，复杂动作不能长期以最低pose代替完成", "未通过对应场景动作验收时本角色章节标记待制作，不缩减首批范围", "任务/奖励仍由主线唯一凭据提交，静态pose不制造英语掌握记录"]})
    npc["special_action_work_orders"] = special_work_orders
    npc["runtime_contract"]["clip_resolution"] = "intersect character required clips, allowed behavior, compatible rig family and capabilities; unresolved bindings remain visibly pending"
    npc["runtime_contract"]["wheelchair_context"] = "Jim's source scene uses seated wheelchair contact. No walk/escort/stand-up clips, inferred medical permanence or unreviewed automatic locomotion. Wheelchair travel, if later needed, requires its own clip and route specification."
    npc["runtime_contract"]["mnemonic_performance"] = "Use mnemonic_story_assets.json. Story rain/cloud/day context uses the performance clock or static panels; ambient weather remains paused."
    npc["production_stages"] = [
        {"id": "P0", "deliverable": "source/identity/contracts only"},
        {"id": "P1", "deliverable": "one human, one island animal, Dino and wheelchair contact samples; wind/water/story integration samples"},
        {"id": "P2", "deliverable": "complete 26-letter prologue and U1 playable loop with required actors plus U2/U3 handoff"},
        {"id": "P3", "deliverable": "all eight books and complete first-batch source-scoped roster chapter by chapter"},
        {"id": "P4", "deliverable": "validated Tripo replacements and expansion"}]
    npc["production_stage_policy"] = "All 142 source-scoped textbook records stay in first-batch scope; finishing all 142 models is not a dependency of the P2 U1 playable loop. Special rig samples are mandatory in P1, not deferred until after bulk human production."
    save("npc_animation_assets.json", npc)
    environment = read(HERE / "environment_motion_assets.json")
    environment["mnemonic_semantic_context_contract"] = manifest["clock_contract"]
    environment["mnemonic_assets_ref"] = "docs/planning/art/mnemonic_story_assets.json"
    save("environment_motion_assets.json", environment)
    print(json.dumps({"miniatures": len(miniature_assets), "orthography": len(symbols), "components": len(components), "samples": len(samples), "integration_sources": len(bridge_sources)}, ensure_ascii=True))


if __name__ == "__main__":
    main()

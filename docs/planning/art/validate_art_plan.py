"""Read-only planning/source audit. Writes reports only beside this script."""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path
import re
import struct
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def stamp():
    try:
        zone = ZoneInfo("Asia/Shanghai")
    except ZoneInfoNotFoundError:
        # Windows embeddable Python may omit tzdata. Current China time is UTC+8.
        zone = timezone(timedelta(hours=8), name="Asia/Shanghai")
    return datetime.now(zone).isoformat()


def write_json(name, data):
    (HERE / name).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def fingerprint(path: Path):
    return {"path": path.relative_to(ROOT).as_posix(), "bytes": path.stat().st_size,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def glb_info(path: Path, scene_id: str):
    with path.open("rb") as f:
        magic, version, total = struct.unpack("<4sII", f.read(12))
        if magic != b"glTF" or version != 2 or total != path.stat().st_size:
            raise ValueError(f"Invalid GLB header: {path}")
        length, kind = struct.unpack("<II", f.read(8))
        if kind != 0x4E4F534A:
            raise ValueError(f"No GLB JSON chunk: {path}")
        raw = f.read(length)
    doc = json.loads(raw)
    primitives = [p for mesh in doc.get("meshes", []) for p in mesh.get("primitives", [])]
    return {
        "scene_id": scene_id, "path": path.relative_to(ROOT).as_posix(),
        "bytes": total, "json_chunk_sha256": hashlib.sha256(raw).hexdigest(),
        "nodes": len(doc.get("nodes", [])), "meshes": len(doc.get("meshes", [])),
        "skins": len(doc.get("skins", [])), "animation_clips": len(doc.get("animations", [])),
        "morph_target_primitives": sum(bool(p.get("targets")) for p in primitives),
        "vertex_color_primitives": sum("COLOR_0" in p.get("attributes", {}) for p in primitives),
        "uv2_primitives": sum("TEXCOORD_1" in p.get("attributes", {}) for p in primitives),
        "sample_environment_nodes": [n.get("name", "") for n in doc.get("nodes", [])
                                     if re.search(r"tree|water|river|crown|fountain", n.get("name", ""), re.I)][:16],
    }


def make_baseline():
    manifest = read_json(ROOT / "game/data/interiors_manifest.json")
    scenes = [("village", ROOT / "game/assets/world/island.glb")]
    scenes += [(room["room_id"], ROOT / "game" / room["game_glb"].removeprefix("res://"))
               for room in manifest["rooms"]]
    models = [glb_info(path, scene_id) for scene_id, path in scenes]
    files = ["game/project.godot", "game/scripts/world_builder.gd", "game/scripts/player.gd",
             "game/scripts/main.gd", "game/scripts/imported_world.gd", "game/scripts/imported_interior.gd",
             "game/scripts/blender_materials.gd", "game/scripts/game_state.gd",
             "game/data/interiors_manifest.json", "game/assets/world/manifest.json"]
    project = (ROOT / files[0]).read_text(encoding="utf-8")
    return {
        "schema_version": 1, "inspected_at": stamp(), "scope": "Source and GLB metadata inspection only; no runtime test.",
        "project_version": re.search(r'config/version="([^"]+)"', project).group(1),
        "renderer": re.search(r'renderer/rendering_method="([^"]+)"', project).group(1),
        "source_files": [fingerprint(ROOT / path) for path in files], "scenes": models,
        "totals": {"scenes": len(models), "interior_scenes": len(manifest["rooms"]),
                   "glb_animation_clips": sum(m["animation_clips"] for m in models),
                   "glb_skins": sum(m["skins"] for m in models),
                   "glb_bytes": sum(m["bytes"] for m in models)},
        "observations": [
            "Current player.gd has procedural limb motion and gestures; GLB clip counts do not measure all game motion.",
            "world_builder.gd constructs character mesh parts and fixed lighting; NPC label and static obstacle are currently separate siblings.",
            "COLOR_0 is used as source albedo. Wind masks must not overwrite it.",
            "Historical v0.3.2 screenshots are art references, not a new capture of v0.4.0.",
        ],
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline-only", action="store_true")
    args = parser.parse_args()
    baseline = make_baseline()
    write_json("current_baseline.json", baseline)
    if args.baseline_only:
        print(json.dumps(baseline["totals"]))
        return
    failures, warnings = [], []
    checks = 0

    def check(ok, text):
        nonlocal checks
        checks += 1
        if not ok:
            failures.append(text)

    scenes = {s["scene_id"] for s in baseline["scenes"]}
    required = ["README.md", "动态美术总策划.md", "环境动态与天气昼夜策划.md", "NPC角色与动作策划.md",
                "教材人物来源核对.md", "角色制作与替换管线.md", "environment_motion_assets.json",
                "npc_animation_assets.json", "textbook_characters.json", "mnemonic_story_assets.json",
                "整合核查与修订.md", "build_art_integration.py"]
    for name in required:
        check((HERE / name).is_file(), f"Missing deliverable: {name}")
    if failures:
        write_json("validation_report.json", {"result": "FAIL", "failures": failures})
        raise SystemExit(1)
    environment = read_json(HERE / "environment_motion_assets.json")
    npc = read_json(HERE / "npc_animation_assets.json")
    textbook = read_json(HERE / "textbook_characters.json")
    mnemonic = read_json(HERE / "mnemonic_story_assets.json")
    for name, data in [("environment", environment), ("npc", npc), ("textbook", textbook), ("mnemonic", mnemonic)]:
        allowed_statuses = {"planning_only"}
        if name == "textbook":
            allowed_statuses.add("planning_source_audit_not_runtime_implementation")
        check(data.get("status") in allowed_statuses, f"{name}: must explicitly be planning/source audit only")
        check(bool(data.get("schema_version")), f"{name}: schema version missing")

    groups = [("environment assets", environment.get("assets", [])), ("npc characters", npc.get("characters", [])),
              ("clips", npc.get("clips", [])), ("behavior states", npc.get("behavior_states", [])),
              ("textbook characters", textbook.get("characters", [])),
              ("mnemonic miniatures", mnemonic.get("miniature_assets", [])),
              ("orthography assets", mnemonic.get("orthography_assets", [])),
              ("mnemonic components", mnemonic.get("stage_components", [])),
              ("mnemonic samples", mnemonic.get("samples", [])),
              ("special rig basic specs", npc.get("special_rig_basic_specs", [])),
              ("special pose specs", npc.get("pose_specs", [])),
              ("special action work orders", npc.get("special_action_work_orders", []))]
    for label, rows in groups:
        check(bool(rows), f"Empty {label}")
        ids = [row.get("id") for row in rows]
        check(all(ids) and len(ids) == len(set(ids)), f"Missing/duplicate IDs in {label}")
        for row in rows:
            for scene_id in row.get("scene_ids", []):
                check(scene_id in scenes, f"{label}:{row['id']}: unknown scene {scene_id}")

    for row in environment["assets"]:
        check(row.get("implementation_status") == "planned", f"{row['id']}: not explicitly planned")
        check(bool(row.get("acceptance")), f"{row['id']}: no acceptance")
        for source in row.get("source_candidates", []):
            if source.get("status") == "existing_verified":
                check((ROOT / source["path"]).exists(), f"{row['id']}: missing claimed existing source {source['path']}")
            else:
                check(source.get("status") == "proposed_new", f"{row['id']}: source status unclear")
    environment_ids = {row["id"] for row in environment["assets"]}
    dependencies = {row["id"]: row.get("dependencies", []) for row in environment["assets"]}
    for asset_id, needed in dependencies.items():
        for dependency in needed:
            check(dependency in environment_ids, f"{asset_id}: unknown dependency {dependency}")
    visited, active = set(), set()

    def acyclic(asset_id):
        if asset_id in active:
            return False
        if asset_id in visited or asset_id not in dependencies:
            return True
        active.add(asset_id)
        result = all(acyclic(parent) for parent in dependencies[asset_id])
        active.remove(asset_id)
        visited.add(asset_id)
        return result

    check(all(acyclic(asset_id) for asset_id in dependencies), "Environment dependency cycle")
    clip_ids = {row["id"] for row in npc.get("clips", [])}
    behavior_ids = {row["id"] for row in npc.get("behavior_states", [])}
    rig_ids = {row["id"] for row in npc.get("rig_families", [])}
    prop_ids = {row["id"] for row in npc.get("planned_props", [])}
    clip_map = {row["id"]: row for row in npc["clips"]}
    rig_map = {row["id"]: row for row in npc["rig_families"]}
    behavior_map = {row["id"]: row for row in npc["behavior_states"]}
    pending_behavior_bindings = []
    planned_pose_bindings = []
    pose_map = {row["id"]: row for row in npc.get("pose_specs", [])}
    special_basic_map = {row["id"]: row for row in npc.get("special_rig_basic_specs", [])}
    work_orders = {row["id"]: row for row in npc.get("special_action_work_orders", [])}
    for row in npc.get("characters", []):
        for clip_id in row.get("required_clip_ids", []):
            check(clip_id in clip_ids, f"Character {row['id']}: missing required clip {clip_id}")
            if clip_id in clip_map:
                check(row.get("rig_family_id") in clip_map[clip_id]["rig_family_ids"],
                      f"Character {row['id']}: incompatible rig for required clip {clip_id}")
        if row.get("rig_family_id"):
            check(row["rig_family_id"] in rig_ids, f"Character {row['id']}: missing rig family")
        for state_id in row.get("behavior_state_ids", []):
            check(state_id in behavior_ids, f"Character {row['id']}: unknown behavior {state_id}")
        bindings = row.get("behavior_clip_bindings", [])
        check([x["state_id"] for x in bindings] == row.get("behavior_state_ids", []),
              f"Character {row['id']}: behavior bindings incomplete or reordered")
        for binding in bindings:
            state = behavior_map.get(binding["state_id"])
            rig = rig_map.get(row.get("rig_family_id"))
            if state is None or rig is None:
                continue
            capable = set(state.get("required_capabilities", [])) <= set(rig.get("planned_capabilities", []))
            check(capable and binding.get("required_capabilities_satisfied_in_plan") is True,
                  f"Character {row['id']}: capability mismatch for {state['id']}")
            expected = [x for x in state["clip_ids"] if x in row.get("required_clip_ids", [])
                        and rig["id"] in clip_map[x]["rig_family_ids"]]
            check(binding.get("candidate_clip_ids") == expected,
                  f"Character {row['id']}: stale/incompatible clip binding for {state['id']}")
            if state["id"] == "offscreen":
                check(binding.get("status") == "logic_only", f"Character {row['id']}: offscreen must be logical")
            elif not expected:
                pose = pose_map.get(binding.get("pose_spec_id"))
                basic = special_basic_map.get(binding.get("planned_spec_id"))
                if pose is not None and basic is not None:
                    check(pose["rig_family_id"] == basic["rig_family_id"] == row["rig_family_id"],
                          f"Character {row['id']}: static pose rig mismatch")
                    check(pose["behavior_state_id"] == state["id"] and pose["id"] in basic["pose_spec_ids"],
                          f"Character {row['id']}: static pose behavior mismatch")
                    check(binding.get("status") == "planned_explicit_pose_fallback_not_tested",
                          f"Character {row['id']}: static pose must remain planned/not tested")
                    planned_pose_bindings.append(f"{row['id']}/{state['id']}")
                    order = work_orders.get(row.get("special_action_work_order_id"))
                    check(order is not None and order["character_id"] == row["id"] and pose["id"] in order["pose_spec_ids"],
                          f"Character {row['id']}: missing concrete production work order")
                else:
                    pending_behavior_bindings.append(f"{row['id']}/{state['id']}")
                    check(False, f"Character {row['id']}: minimum behavior has neither compatible clip nor explicit pose spec")
        if row.get("rig_family_id") == "wheelchair_humanoid_v1":
            check(not {"escort", "travel_to_anchor", "seated_work"} & set(row.get("behavior_state_ids", [])),
                  f"Character {row['id']}: unplanned walking/standing assigned")
            check(all(x.startswith("wheelchair_") for x in row.get("required_clip_ids", [])),
                  f"Character {row['id']}: wheelchair context must use explicit adapted clips")
    for row in npc.get("clips", []):
        check(row.get("status") == "planned", f"Clip {row['id']}: not planned")
        for rig_id in row.get("rig_family_ids", []):
            check(rig_id in rig_ids, f"Clip {row['id']}: missing rig family {rig_id}")
        for prop_id in row.get("prop_ids", []):
            check(prop_id in prop_ids, f"Clip {row['id']}: missing prop {prop_id}")
    for row in npc.get("behavior_states", []):
        for clip_id in row.get("clip_ids", []):
            check(clip_id in clip_ids, f"Behavior {row['id']}: missing clip {clip_id}")
        for state_id in row.get("exit_to", []):
            check(state_id in behavior_ids, f"Behavior {row['id']}: missing exit state {state_id}")
    for pose in pose_map.values():
        check(pose["rig_family_id"] in rig_ids and pose["behavior_state_id"] in behavior_ids,
              f"Pose {pose['id']}: unknown rig/behavior")
        check(pose.get("implementation_status") == "planned" and pose.get("representation") == "static_key_pose",
              f"Pose {pose['id']}: must distinguish planned static pose from animation")
        check(bool(pose.get("specification")) and bool(pose.get("acceptance")) and bool(pose.get("source_candidates")),
              f"Pose {pose['id']}: incomplete production specification")
        check(pose.get("source_file") is None and pose.get("source_file_status") == "not_created",
              f"Pose {pose['id']}: this planning package must not claim produced source")
    for basic in special_basic_map.values():
        check(basic.get("implementation_status") == "planned" and basic.get("production_stage") == "P3",
              f"Basic rig spec {basic['id']}: production state mismatch")
        linked = [pose_map[x] for x in basic["pose_spec_ids"] if x in pose_map]
        check(len(linked) == 2 and {x["behavior_state_id"] for x in linked} == {"idle", "event_wait"},
              f"Basic rig spec {basic['id']}: requires both concrete minimum poses")
    special_actor_ids = {row["id"] for row in npc["characters"] if row.get("special_action_work_order_id")}
    check({row["character_id"] for row in work_orders.values()} == special_actor_ids and len(work_orders) == len(special_actor_ids),
          "Special action work orders must cover each special actor once")
    for order in work_orders.values():
        check(order.get("implementation_status") == "planned" and order.get("production_stage") == "P3",
              f"Work order {order['id']}: must remain planned P3")
        check(order["basic_spec_id"] in special_basic_map and all(x in pose_map for x in order["pose_spec_ids"]),
              f"Work order {order['id']}: unresolvable minimum pose specs")
        check(bool(order.get("required_action_semantics")) and bool(order.get("deliverables")) and bool(order.get("acceptance")),
              f"Work order {order['id']}: missing required action/production/acceptance")
        check(order.get("required_before") == "this_character_corresponding_chapter_release" and
              order.get("source_action_breakdown_status") == "pending_corresponding_source_scene_editorial_review",
              f"Work order {order['id']}: source-specific action gate missing")

    textbook_ids = {row["id"] for row in textbook["characters"]}
    source_books = {}
    for entry in textbook.get("source_books", []):
        path = Path(entry["manifest_path"])
        check(path.is_file(), f"Missing textbook manifest: {path}")
        if path.is_file():
            check(hashlib.sha256(path.read_bytes()).hexdigest() == entry["manifest_sha256"],
                  f"Textbook manifest fingerprint changed: {entry['book_id']}")
            source_books[entry["book_id"]] = read_json(path)
    check(len(source_books) == 8, "Expected eight source textbooks")
    mapped_ids = set()
    mapping_counts = Counter()
    for row in npc["characters"]:
        source_id = row.get("textbook_character_id")
        if source_id:
            mapped_ids.add(source_id)
            mapping_counts[source_id] += 1
            check(source_id in textbook_ids, f"NPC {row['id']}: invalid textbook ID {source_id}")
            check(row.get("first_batch") is True, f"NPC {row['id']}: textbook role omitted from first batch")
    check(textbook_ids == mapped_ids, "Textbook/NPC source ID sets must match exactly")
    check(all(count == 1 for count in mapping_counts.values()), "Each source-scoped textbook identity must map to exactly one NPC record")
    source_role_ids = {row["id"] for row in textbook.get("unnamed_roles_pending", [])}
    npc_role_ids = {row.get("source_role_id") for row in npc.get("textbook_role_slots", [])}
    check(source_role_ids <= npc_role_ids, "Unnamed textbook role slots not fully preserved")
    check(source_role_ids == npc_role_ids and len(npc_role_ids) == len(npc.get("textbook_role_slots", [])),
          "Unnamed role mapping must be one-to-one at source role-group level")
    object_ids = {row["id"] for row in textbook.get("named_objects", [])}
    planned_objects = npc.get("named_object_asset_candidates", [])
    check({row["source_object_id"] for row in planned_objects} == object_ids, "Named object asset mapping incomplete")
    check(all(row.get("npc") is False and not row.get("behavior_state_ids") for row in planned_objects),
          "Named objects must not inherit NPC schedules")
    for row in textbook["characters"]:
        check(row.get("first_batch") is True, f"Textbook {row['id']}: not first batch")
        check(bool(row.get("source_refs")), f"Textbook {row['id']}: no evidence references")
        for ref in row.get("source_refs", []):
            book = source_books.get(ref.get("book_id"))
            check(book is not None, f"{row['id']}: unknown source book")
            if book is None:
                continue
            page_index = int(ref["file_page"]) - 1
            check(0 <= page_index < len(book["pages"]), f"{row['id']}: source file page out of range")
            if not 0 <= page_index < len(book["pages"]):
                continue
            page = book["pages"][page_index]
            check(Path(ref["image_path"]).is_file(), f"{row['id']}: source image missing")
            if ref.get("region_id"):
                regions = {region["id"]: region for region in page.get("regions", [])}
                region = regions.get(ref["region_id"])
                check(region is not None, f"{row['id']}: source region missing {ref['region_id']}")
                if region:
                    check(region.get("text") == ref.get("text"), f"{row['id']}: source text mismatch {ref['region_id']}")
            if "printed_page" in ref:
                check(str(ref["printed_page"]) == str(page.get("printedPage")), f"{row['id']}: printed page mismatch")

    vocabulary = read_json(ROOT / "docs/planning/vocabulary/data/catalog.json")
    integration = read_json(ROOT / "docs/planning/vocabulary/data/integration_contract.json")
    adapter = read_json(ROOT / "docs/planning/vocabulary/data/mainline_entries.json")
    adapted = {row["entry_id"]: row for row in adapter["entries"]}
    lexemes = {row["id"]: row for row in vocabulary["lexemes"]}
    stories = {row["id"]: row for row in vocabulary["stories"]}
    occurrences = {row["id"]: row for row in vocabulary["occurrences"]}
    prologue = read_json(ROOT / "docs/planning/mainline/alphabet_prologue.json")
    prologue_letters = {row["letter"]["uppercase"]: row for row in prologue["letters"]}
    codebook = {row["letter"]: row for row in integration["codebook"]}
    check(mnemonic["content_revision"] == integration["content_revision"] == adapter["content_revision"], "Mnemonic content revision stale")
    check(mnemonic["codebook_revision"] == integration["codebook_revision"] == adapter["codebook_revision"], "Mnemonic codebook revision stale")
    for row in mnemonic["source_snapshot"] + mnemonic["integration_sources"]:
        target = ROOT / row["path"]
        check(target.is_file() and hashlib.sha256(target.read_bytes()).hexdigest() == row["sha256"],
              "Mnemonic source changed; regenerate art interface: " + row["path"])
    miniatures = mnemonic["miniature_assets"]
    check([x["letter"] for x in miniatures] == list("ABCDEFGHIJKLMNOPQRSTUVWXYZ"), "Need exactly ordered 26 mnemonic miniatures")
    all_mnemonic_assets = miniatures + mnemonic["orthography_assets"] + mnemonic["stage_components"]
    mnemonic_ids = {row["id"] for row in all_mnemonic_assets}
    check(len(mnemonic_ids) == len(all_mnemonic_assets), "Mnemonic asset IDs must be globally unique")
    for row in all_mnemonic_assets:
        check(row.get("implementation_status") == "planned", f"{row['id']}: new art not explicitly planned")
        check(bool(row.get("acceptance")), f"{row['id']}: no acceptance criteria")
        for candidate in row.get("source_candidates", []):
            if candidate.get("status") == "existing_verified":
                check((ROOT / candidate["path"]).is_file(), f"{row['id']}: missing existing source")
    for row in miniatures:
        letter = row["letter"]
        check(row["canonical_anchor_en"] == codebook[letter]["anchor_en"] == prologue_letters[letter]["anchor"]["canonical_word"],
              f"{letter}: anchor conflict across vocabulary/prologue/art")
        check(row["codebook_asset_identity"] == codebook[letter]["asset_identity"], f"{letter}: codebook asset ID mismatch")
        check(row["landmark_room_id"] == codebook[letter]["landmark_room_id"], f"{letter}: landmark binding mismatch")
        check(row["canonical_word_zh"] == codebook[letter]["canonical_word_zh"], f"{letter}: canonical meaning mismatch")
    egg = next(row for row in miniatures if row["letter"] == "E")
    check(egg["canonical_word_zh"] == "鸡蛋" and "完整蛋形" in egg["representative_label_zh"], "Egg meaning/representative distinction lost")
    token_types = {token["type"] for lexeme in lexemes.values() for token in lexeme["tokens"]} - {"letter"}
    symbol_types = {row["token_type"] for row in mnemonic["orthography_assets"]}
    check(symbol_types == token_types | {"diacritic"}, "Non-letter/modifier asset coverage mismatch")
    check([(row["id"], row["source_level"]) for row in mnemonic["prompt_levels"]] == [(f"H{i}", i) for i in range(6)], "H0-H5 level mapping mismatch")
    for sample in mnemonic["samples"]:
        lexeme = lexemes.get(sample["lexeme_id"])
        story = stories.get(sample["story_id"])
        check(lexeme is not None and story is not None, f"Sample {sample['id']}: unknown lexeme/story")
        if lexeme is None or story is None:
            continue
        check(story["lexeme_id"] == lexeme["id"] and sample["sense_id"] == story["id"], f"Sample {sample['id']}: identity chain mismatch")
        check(sample["spelling"] == lexeme["spelling"] == "".join(x["raw"] for x in sample["tokens"]), f"Sample {sample['id']}: spelling reconstruction mismatch")
        check(len(sample["tokens"]) == len(lexeme["tokens"]), f"Sample {sample['id']}: token count mismatch")
        cursor = 1
        for derived, original in zip(sample["tokens"], lexeme["tokens"]):
            check(all(derived.get(key) == value for key, value in original.items()), f"Sample {sample['id']}: source token changed")
            check(derived["surface_position"] == cursor, f"Sample {sample['id']}: non-contiguous raw position")
            cursor += len(derived["raw"])
            check(derived["asset_id"] in mnemonic_ids, f"Sample {sample['id']}: unknown token asset")
            if derived.get("modifier_asset_id"):
                check(derived["modifier_asset_id"] in mnemonic_ids, f"Sample {sample['id']}: unknown modifier asset")
        check(len({x["instance_id"] for x in sample["tokens"]}) == len(sample["tokens"]), f"Sample {sample['id']}: duplicate token instance")
        check(sample["frames"] == story["frames"] and sample["storage"] == story["storage"], f"Sample {sample['id']}: source frame/storage mismatch")
        check([p for frame in sample["frames"] for p in frame["letter_positions"]] == list(range(1, len(lexeme["letter_chain"]) + 1)), f"Sample {sample['id']}: encoding order/repetition mismatch")
        for entry_id in sample["entry_ids"]:
            occurrence = occurrences.get(entry_id)
            check(occurrence is not None and occurrence["story_id"] == sample["story_id"] and occurrence["lexeme_id"] == sample["lexeme_id"], f"Sample {sample['id']}: occurrence identity mismatch")
            check(entry_id in adapted, f"Sample {sample['id']}: missing adapted occurrence")
        if sample["entry_ids"] and sample["entry_ids"][0] in adapted:
            entry = adapted[sample["entry_ids"][0]]
            check(sample["adapter_letter_slots"] == entry["letter_slots"], f"Sample {sample['id']}: adapter positions mismatch")
            check(sample["adapter_memory_home"] == entry["memory_home"], f"Sample {sample['id']}: adapter memory home mismatch")
        for permission in sample["entry_permissions"]:
            check(permission["task_permissions"] == adapted[permission["entry_id"]]["task_permissions"], f"Sample {sample['id']}: curriculum permissions changed")
    longest = next(row for row in mnemonic["samples"] if row["spelling"] == "International Children's Day")
    check(longest["letter_count"] == 25 and longest["frame_count"] == 7 and longest["spelling_gate"] == "optional_recognition_scaffold_not_forced_spelling", "Longest sample must remain optional recognition, 25 letters and seven frames")
    check(environment.get("mnemonic_semantic_context_contract") == mnemonic["clock_contract"], "Story/weather clock contracts differ")
    check([row["id"] for row in npc.get("production_stages", [])] == ["P0", "P1", "P2", "P3", "P4"], "Production stage contract mismatch")

    for path in HERE.glob("*.md"):
        content = path.read_text(encoding="utf-8")
        for target in re.findall(r"\]\(([^)]+)\)", content):
            target = target.strip().strip("<>").split("#", 1)[0]
            if not target or re.match(r"(?:https?|codex)://", target):
                continue
            if (path.parent / target).resolve() == HERE / "validation_report.json":
                continue  # This run writes the report after validating its inputs.
            check((path.parent / target).exists(), f"{path.name}: missing local link {target}")

    warnings.append("Planning verification only: no character binding, weather implementation, in-engine animation review or performance test.")
    warnings.append(f"{len(planned_pose_bindings)} character/behavior bindings resolve to explicit planned static pose specs, not produced animations; {len(work_orders)} source-scene action work orders still require editorial breakdown and production before their chapter release.")
    report = {"schema_version": 1, "validated_at": stamp(), "result": "FAIL" if failures else "PASS",
              "checks": checks, "source_scene_count": len(scenes),
              "counts": {label: len(rows) for label, rows in groups},
              "textbook_character_ids_covered": len(mapped_ids),
              "textbook_candidates_count": len(textbook.get("candidate_mentions", [])),
              "textbook_named_objects_count": len(textbook.get("named_objects", [])),
              "pending_behavior_bindings": pending_behavior_bindings,
              "planned_pose_bindings": planned_pose_bindings,
              "mnemonic_source_counts": mnemonic["source_counts"],
              "failures": failures, "limitations": warnings,
              "planning_files": [fingerprint(path) for path in sorted(HERE.glob("*"))
                                 if path.is_file() and path.name not in {"validation_report.json", "current_baseline.json"}]}
    write_json("validation_report.json", report)
    print(json.dumps({key: report[key] for key in ["result", "checks", "counts", "failures"]}, ensure_ascii=True))
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()

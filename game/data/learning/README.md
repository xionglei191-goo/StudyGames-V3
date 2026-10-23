# Offline learning package

Rebuild from repository planning data only:

```powershell
python -X utf8 scripts/build_learning_content.py
python -X utf8 scripts/build_learning_content.py --verify-only
```

`catalog.json` uses `learning-content-v1`: eight `books`, 1314 `entries`, deduplicated `lexemes` and `stories`, 81-item `unit_index`, 26-item `codebook`, source references and explicit review status. Runtime does not read the original textbook directory. The 26 original SVGs are also embedded in `codebook[].svg_source`, so imported or exported builds do not require raw SVG source files.

`res://ui/memory_story_content.gd` provides static `load_catalog()`, `get_entry(entry_id)`, `list_entries(book_id, unit_id, query)` and `icon(letter)`. `get_entry` expands the shared records into the component's input. Use the returned `entry_id`, `content_revision` and `codebook_revision` unchanged.

`res://ui/memory_story.gd` extends `Control`. Add an instance to its host and call `setup(entry, resume_state)`. It fills its host, scrolls vertically, and has no direct State dependency. Signals `help_shown`, `response_submitted`, `progress_changed` and `close_requested` each emit one Dictionary. Connect them before setup so the first actual H5 exposure is recorded.

Resume includes invocation/attempt IDs, one-based `current_beat`, `seen_beats` IDs, support level, actual cue history, first/later responses, view mode, draft writing, revealed gaps, bridge position and sequence visibility. `seen_beats` records fully shown H5 frames; partial clues do not pretend the full frame was shown. A version mismatch returns `content_unavailable` without replacing the saved version. `completed` closes a browsing/practice session and does not assert mastery.

Optional writing uses `meaning_to_spelling` with the Chinese gloss as declared stimulus. H0 cannot erase earlier help. H3 hides missing images and adjacent action prose that could reveal them. Replaying a complete spelling is H5. Exact existing bundled audio is offered for seven occurrences; it is not used to generate listening or pronunciation passes. Time fields use UTC Unix seconds.

The content information panel states that independent editorial review and child testing remain pending. Full runtime course events are implemented separately; `curriculum_arcs.json` is a source-backed chapter catalog, not proof that all 81 events are playable.

Component validation:

```powershell
& 'F:/Tools/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --fixed-fps 60 --path game --script res://tests/test_memory_story.gd -- --test-harness
```

This test does not run a global import or instantiate the full game scene. It writes `.local/validation/memory-story-report.json` and checks the production save hashes. Add `--capture` without `--headless` for the three rendered screenshots.

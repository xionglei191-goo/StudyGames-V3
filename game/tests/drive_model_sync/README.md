# Drive own16 model-sync validation

These four snapshots preserve the existing gameplay checks and write this run's
reports to `docs/verification/drive-model-sync-own16-20261027/headless/`.
They do not replace the original test scripts or production scripts.

`copy-manifest.json` records each original and copy SHA-256 and every replacement.
Reversing the listed replacements reproduces the original bytes exactly.

| Entry | Changes from the existing test |
| --- | --- |
| `test_movement.gd` | Redirect the report directory from `.local/validation`. |
| `test_school_hierarchy.gd` | Inherit the isolated movement copy so its finish method writes the new report directory. |
| `test_world_refinement.gd` | Inherit the isolated school copy; redirect its own world-refinement report directory. |
| `test_home_indoor.gd` | Redirect `INDOOR_REPORT_DIR`; retain the original home-exterior parent and all household logic. Its overridden finish method handles the report. |

No assertion, route, requested letter, interaction, timeout, save guard, cleanup,
or exit-code rule is weakened. The complete A-Z journey remains the default.
All four suites require `-- --test-harness`, use process-specific validation saves,
and check the protected production save hashes. The inherited startup refuses a
run without that flag.

Prepare/import the new assets first. Do not start these suites while an import or
native screenshot session is running. The runner starts at most two headless
processes, records stdout/stderr separately, and archives each suite report under
the corresponding timestamped run directory before producing `summary.json`.
It requires an existing Godot binary; it does not import assets or launch a GUI.

```powershell
pwsh -NoProfile -File .\game\tests\drive_model_sync\run-headless-suites.ps1
```

Individual invocation, after the model import completes:

```powershell
& 'F:\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --fixed-fps 60 --path 'F:\LoveStudy\game' --script 'res://tests/drive_model_sync/test_world_refinement.gd' -- --test-harness
```

Preparation verified the byte transformations only. Gameplay acceptance requires
actual execution and the generated reports; no passing result is implied by the
existence of these copies.

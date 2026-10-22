"""Build into a new scene in Blender; stops if that scene already exists.
A source orchard .blend, layout.json, and available Tripo GLBs must be in place.
Does not save or overwrite any existing .blend/GLB file.
"""
import importlib.util
import sys
from pathlib import Path
BASE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('studygame_world',BASE/'world_builder.py')
w=importlib.util.module_from_spec(spec);sys.modules[spec.name]=w;spec.loader.exec_module(w)
w.initialize();w.build_terrain();w.build_paths_and_plots()
w.refresh_landmarks();w.copy_orchard();w.build_home();w.decorate();w.configure_view()
exec(compile((BASE/'refine_map.py').read_text(),'refine_map.py','exec'),{'__name__':'__main__'})
print('Map built. Inspect camera views, then save a new .blend file.')

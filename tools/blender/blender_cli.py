"""Minimal `blender` CLI shim over the bpy module (no binary build available here).
Supports: -b/--background, [file.blend], --factory-startup, --python-exit-code N,
-P/--python FILE, --python-expr EXPR, --version, and `--` passthrough args."""
import sys, os, runpy, traceback
argv = sys.argv[1:]
rest = []
if "--" in argv:
    i = argv.index("--"); argv, rest = argv[:i], argv[i:]
import bpy
if "--version" in argv or "-v" in argv:
    print("Blender", bpy.app.version_string); sys.exit(0)
exit_code, actions, blend = 0, [], None
i = 0
while i < len(argv):
    a = argv[i]
    if a in ("-b", "--background", "--factory-startup", "-noaudio", "--disable-autoexec", "-y", "--enable-autoexec"): pass
    elif a == "--python-exit-code": exit_code = int(argv[i + 1]); i += 1
    elif a in ("-P", "--python"): actions.append(("file", argv[i + 1])); i += 1
    elif a == "--python-expr": actions.append(("expr", argv[i + 1])); i += 1
    elif a.endswith(".blend") and blend is None: blend = a
    else: print("blender shim: ignoring arg", a, file=sys.stderr)
    i += 1
bpy.ops.wm.read_factory_settings(use_empty=False)
if blend: bpy.ops.wm.open_mainfile(filepath=os.path.abspath(blend))
sys.argv = [sys.argv[0]] + argv + rest  # scripts read args after '--'
try:
    for kind, v in actions:
        if kind == "file": runpy.run_path(v, run_name="__main__")
        else: exec(compile(v, "<expr>", "exec"), {"__name__": "__main__", "bpy": bpy})
except SystemExit as e:
    sys.exit(e.code)
except Exception:
    traceback.print_exc(); sys.exit(exit_code)

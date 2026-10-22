"""처용: gat with a peony, teal hanbok with white trim, red sash, bamboo flute. blender -b -P art/b3d/cheoyong.py -- <out.glb|render_dir>"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C
import chibi

SPEC = {"skin": (0.93, 0.68, 0.52), "hair": (0.08, 0.06, 0.07), "jeogori": (0.32, 0.6, 0.62), "trim": (0.92, 0.9, 0.84),
        "sash": (0.78, 0.12, 0.2), "pants": (0.17, 0.2, 0.33), "shoe": (0.92, 0.9, 0.85), "hat": "gat",
        "hat_color": (0.06, 0.07, 0.1), "flower": (0.95, 0.38, 0.55), "prop": "flute"}

if __name__ == "__main__":
    out, only, res = C.args()
    C.reset()
    R = chibi.build(SPEC)
    pose = chibi.make_pose(R)
    if out.endswith(".glb"):
        C.export_glb(R["root"], pose, chibi.CLIPS, out, scale=1.2)
    else:
        C.setup_render(res, ortho=2.35)
        C.frame(R["root"], pose)
        C.render_all(R["root"], pose, {"idle": (1, C.DIRS8), "walk": (6, C.D5), "attack": (6, C.D3)}, out, only)

#!/bin/sh
# Install Blender 5.2 headless in a cloud container: the bpy wheel from PyPI (download.blender.org is blocked),
# a `blender` command shim over it (tools/blender/blender_cli.py), and the blender-* agent skills (EL4CTEO/blender-skills).
# Only Cycles renders here (no GPU/EGL for EEVEE or Workbench).
set -e
D=/opt/blender
HERE="$(cd "$(dirname "$0")" && pwd)"
[ -x $D/venv/bin/python ] || python3.13 -m venv $D/venv
$D/venv/bin/python -c "import bpy" 2>/dev/null || $D/venv/bin/pip install -q bpy==5.2.2
cp "$HERE/blender/blender_cli.py" $D/blender_cli.py
printf '#!/bin/sh\nexec %s/venv/bin/python %s/blender_cli.py "$@"\n' $D $D > /usr/local/bin/blender
chmod +x /usr/local/bin/blender
if [ ! -d ~/.claude/skills/blender-core ]; then
  rm -rf /tmp/blender-skills
  GIT_LFS_SKIP_SMUDGE=1 git clone -q --depth 1 https://github.com/EL4CTEO/blender-skills /tmp/blender-skills
  bash /tmp/blender-skills/install/install.sh --agent claude --copy
fi
blender --version

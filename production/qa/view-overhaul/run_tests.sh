#!/bin/bash
cd "$(dirname "$0")/../../.."
G=~/workspace/tools/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64
L=~/workspace/goals/rpg/hidden_files/godot.lock
O=$PWD/production/qa/view-overhaul
mkdir -p $O/logs
flock $L timeout 600 xvfb-run -a -s "-screen 0 2556x1179x24" $G --path src -- --capture=$O/after_fight.png --winsize=2556x1179 --level=beach --beach-fight --frames=420 2>&1 | grep -E "VIEWPORT|SCRIPT ERROR" > $O/logs/fight.log
echo CAPS_DONE
for t in hud_layout view_range; do echo "== $t"; flock $L bash tests/$t.sh 2>&1 | tail -8; done > $O/logs/t1.log 2>&1
python3 tests/beach_bounds.py > $O/logs/bounds.log 2>&1
flock $L bash tests/art_walk.sh beach > $O/logs/walk.log 2>&1
flock $L bash tests/smoke_godot.sh > $O/logs/smoke.log 2>&1
flock $L bash tests/combat_strategy.sh > $O/logs/combat.log 2>&1
echo ALL_DONE > $O/logs/done.txt

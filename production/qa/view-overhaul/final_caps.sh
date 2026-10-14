#!/bin/bash
cd ~/workspace/goals/rpg/dev/wt-view-overhaul
G=~/workspace/tools/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64
L=~/workspace/goals/rpg/hidden_files/godot.lock
O=$PWD/production/qa/view-overhaul
c() { n=$1; r=$2; shift 2; flock $L timeout 600 xvfb-run -a -s "-screen 0 ${r}x24" $G --path src -- --capture=$O/$n.png --winsize=$r --level=beach "$@" 2>&1 | grep -E "VIEWPORT|SCRIPT ERROR" >> $O/logs/final.log; }
: > $O/logs/final.log
c after_fight 2556x1179 --beach-fight --frames=420
c after_169 1920x1080 --beach-fight --frames=420
c after_touch 2556x1179 --touch --beach-fight --frames=420
flock $L bash tests/view_range.sh > $O/logs/view_range_all.log 2>&1
flock $L bash tests/art_walk.sh beach gyeongju > $O/logs/walk2.log 2>&1
echo done > $O/logs/final_done.txt

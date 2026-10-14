#!/bin/bash
G=~/workspace/tools/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64
L=~/workspace/goals/rpg/hidden_files/godot.lock
O=~/workspace/goals/rpg/dev/wt-view-overhaul/production/qa/view-overhaul/logs
for t in "wt-view-before boss_main" "wt-view-overhaul boss_mine"; do
  set -- $t
  cd ~/workspace/goals/rpg/dev/$1/src
  s=$(date +%s)
  flock $L timeout 400 xvfb-run -a $G --path . --rendering-driver opengl3 -- --boss --capture=$O/$2.png --frames=400 > $O/$2.log 2>&1
  echo "rc=$? secs=$(( $(date +%s)-s ))" >> $O/$2.log
done
echo fin > $O/boss_done.txt

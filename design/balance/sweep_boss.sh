#!/usr/bin/env bash
# usage: sweep.sh HP IDLE OPEN N LIMIT
CAST=${6:-1.25}; HP=$1; ID=$2; OP=$3; N=$4; LIM=$5
R=~/workspace/goals/rpg/dev/wt-prog-balance
D=~/balwork/sw/hp${HP}_i${ID}_o${OP}_c${CAST}_n${N}
rm -rf $D; mkdir -p $D/tests; cp -r $R/src $D/src; cp -r $R/tests/godot $D/tests/godot
sed -i -E "s/^const BOSS_CAST_MULT := [0-9.]+/const BOSS_CAST_MULT := $CAST/" $D/src/scripts/combat_tuning.gd
sed -i -E "s/^const BOSS_HP := [0-9.]+/const BOSS_HP := $HP/; s/^const BOSS_IDLE_MULT := [0-9.]+/const BOSS_IDLE_MULT := $ID/; s/^const BOSS_OPEN_MULT := [0-9.]+/const BOSS_OPEN_MULT := $OP/" $D/src/scripts/combat_tuning.gd
sed -i -E "s/var n := 3/var n := $N/; s/, 150\.0\)/, ${LIM}.0)/" $D/tests/godot/balance_probe.gd
sed -i -E "s/const BOSS_MAX := [0-9.]+/const BOSS_MAX := $HP.0/" $D/tests/godot/harness.gd
mkdir -p $D/data
G=$HOME/workspace/tools/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64
flock ~/workspace/goals/rpg/hidden_files/godot.lock env XDG_DATA_HOME=$D/data timeout 3000 $G --headless --fixed-fps 60 --path $D/src -s ../tests/godot/balance_probe.gd -- --scn=boss --level=pyega2 2>&1 | grep -E "^(RES|FAIL|SCRIPT ERROR|SCN_RESULT)" > $D/out.txt
echo "CFG cast=$CAST hp=$HP idle=$ID open=$OP n=$N lim=$LIM"  >> ~/balwork/sw/all.txt; cat $D/out.txt >> ~/balwork/sw/all.txt

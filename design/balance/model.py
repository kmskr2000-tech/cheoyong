#!/usr/bin/env python3
"""전투 밸런스 해석 모델 — src/scripts 의 상수에서 직접 옮긴 값으로 계산 (게임 코드 미수정).
사용: python3 design/balance/model.py"""
import math
# ---- 정본 (combat_tuning.gd / player.gd / enemy.gd / boss.gd)
COMBO = [(10, .26), (10, .26), (18, .34)]
KINDS = {  # hp, tell, strike, dmg, armor, stagger_after
 "dog": (30, .4, .28, 8, 1.0, .5), "ghoul": (40, .5, .25, 10, 1.0, 0), "sea": (44, .9, .3, 12, 1.0, .8),
 "mulgwi": (44, .7, .35, 10, 1.0, 0), "maiden_ghost": (40, .9, .4, 6, 1.0, 0),
 "egg_ghost": (36, .5, .32, 10, 1.0, 0), "mama": (70, .8, .35, 12, .6, 1.2)}
def mult(lv): return 1 + (lv - 1) * .05
def chain(lv, armor=1.0, stag=1.0):
    m = mult(lv); out = []
    for d, t in COMBO:
        v = round(d * m); v = math.ceil(v * (armor if stag == 1.0 else stag)); out.append((v, t))
    return out
def charge_dmg(lv, c):
    t = min(1, max(0, (c - .35) / .55)); return round(18 * (1.3 + 1.2 * t) * mult(lv))
print("== 플레이어 피해 (Lv2/Lv3)")
for lv in (2, 3):
    ch = chain(lv); tot = sum(v for v, _ in ch); tm = sum(t for _, t in ch)
    print(f"Lv{lv} mult={mult(lv):.2f} 3연타 {[v for v,_ in ch]} 합{tot}/{tm:.2f}s = {tot/tm:.1f} DPS ; 강베기 c=.35:{charge_dmg(lv,.35)} c=.9:{charge_dmg(lv,.9)}"
          f" (소요 {0.45+.35:.2f}~{.45+.9:.2f}s + 후딜.35 → 만충 DPS {charge_dmg(lv,.9)/(0.45+.9+.35):.1f})")
print("\n== 요괴별 처치 이론값 (Lv2, 정지 표적, 이동 제외)")
for k, (hp, tell, strike, dmg, arm, sa) in KINDS.items():
    # 3연타 반복으로 hp 를 깎는 시간 (콤보 1회 0.86s, 3타째 도달 시각 = .26+.26+.34*.4+...)
    ch = chain(2, arm); left = hp; t = 0.0; n = 0
    hit_t = [0.26 * .4, 0.26 + 0.26 * .4, 0.52 + 0.34 * .4]
    cyc = 0; done_t = None
    while left > 0 and cyc < 6:
        for i, (v, d) in enumerate(ch):
            left -= v
            if left <= 0:
                done_t = cyc * .86 + hit_t[i]; break
        cyc += 1
    cv = charge_dmg(2, .9)
    one_shot = cv >= hp
    print(f"{k:13s} HP{hp:3d} 예고{tell}+타격{strike}={tell+strike:.2f}s  3연타 처치 {done_t:.2f}s (콤보 {cyc}회)  만충 1회 {cv} {'일격' if one_shot else '불충분'}  타격 1회 {dmg}")
print("\n== 구르기 연타 가용도")
RT, LOCK = .32, .25
print(f"사이클 {RT+LOCK:.2f}s, 무적 {RT/(RT+LOCK):.0%}, 받아넘기기 창 .15 → {0.15/(RT+LOCK):.0%}(사이클 기준)/{.15/RT:.0%}(구르기 기준)")
print("무적 공백 .25s vs 요괴 타격 지속: " + ", ".join(f"{k} {v[2]}s" for k, v in KINDS.items()))
print("\n== 역신 사이클 (1페이즈, 기대 노출)")
idle1, idle2 = 1.4, 1.0
cyc1 = [("fog", .9, 1.25), ("idle", idle1, 1.0), ("cough", 1.0, 1.0), ("open", 1.2, 1.5), ("idle", idle1, 1.0),
        ("clones", .8, 1.25), ("idle", idle1, 1.0), ("cough", 1.0, 1.0), ("open", 1.2, 1.5), ("idle", idle1, 1.0)]
T1 = sum(s for _, s, _ in cyc1); E1 = sum(s * m for _, s, m in cyc1)
print(f"1페이즈 사이클 {T1:.1f}s, 유효 1배초 {E1:.1f} (노출 평균 {E1/T1:.2f}배)")
cyc2 = [("fog", .9 / 1.35, 1.25), ("idle", idle2, 1), ("cough", 1.0 / 1.35, 1), ("cough2", .45 / 1.35 + 0, 1), ("open", .9, 1.5), ("idle", idle2, 1),
        ("clones", .8, 1.25), ("idle", idle2, 1), ("cough", 1.0 / 1.35, 1), ("cough2", .45 / 1.35, 1), ("open", .9, 1.5), ("idle", idle2, 1),
        ("fog", .9 / 1.35, 1.25), ("idle", idle2, 1), ("clones", .8, 1.25), ("idle", idle2, 1)]
T2 = sum(s for _, s, _ in cyc2); E2 = sum(s * m for _, s, m in cyc2)
print(f"2페이즈 사이클 {T2:.1f}s, 유효 1배초 {E2:.1f} (노출 평균 {E2/T2:.2f}배)")
for lv in (3,):
    ch = chain(lv); dps = sum(v for v, _ in ch) / sum(t for _, t in ch)
    for up in (1.0, .6, .4):
        # 1페이즈: HP 240 소진, 2페이즈 240
        p1 = 240 / (dps * up * E1 / T1); p2 = 240 / (dps * up * E2 / T2)
        print(f"Lv{lv} DPS {dps:.1f} 가동률 {up:.0%}: 1페이즈 {p1:.0f}s + 2페이즈 {p2:.0f}s = {p1+p2:.0f}s (+전환열림1.2s)")
print("\n== 역신 위협 (플레이어 HP Lv3=112)")
print("숨결14 ×사이클당 2회(1P) → 사이클 28 HP 위험, 펄스12, 안개 5/0.5s(TEAR시 3), 졸개 10/타(2P 3마리)")

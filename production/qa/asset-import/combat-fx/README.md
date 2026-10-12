# 전투 신호 이펙트 전/후 (아트팀, 2026-10-12)
`*_before_zoom.png` = 기준 커밋 642f5ee, `*_after_zoom.png` = asset/combat-fx (플레이어 주변 4배 확대). 캡처: `tests/fx_shots.sh <src> before|after <out>` (tests/godot/fx_shots.gd).
장면: parry(받아넘기기) · charge(충전 오라 a/b/c/d, 적중 e=관통) · guard(수호부 a=막음 b=파괴+소리환급) · open(적 후딜 약점) · boss_open(역신 열림) · bindfire(결박·화염 ×1.6) · purify(쓰러짐 a→정화 b) · tell(예고 굳음, after만 — 기준 커밋엔 신호 없음).
시트 원본은 art/fx.py → src/assets/fx/*.png, 연결은 src/scripts/fx/combat_fx.gd.
감사 지적 3건 수정 후 parry/bindfire/tell after 샷 갱신(2026-10-12 22시대).

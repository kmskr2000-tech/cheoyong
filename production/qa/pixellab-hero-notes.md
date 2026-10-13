# Pixellab 처용 도트 테스트 (2026-10-14, 무료 플랜)

## 산출물
- production/art/pixellab/cheoyong_pixellab_sheet.png (256x384, 셀 64x64, 4열 x 6행) + .json (동작/프레임수/크기/fps)
- 행: idle_east, walk_east, attack_east, hit_east, idle_west(좌우반전), walk_west(좌우반전)
- compare_old_vs_pixellab.png: 기존 처용(32x48 첫 프레임, 맨 왼쪽) vs Pixellab walk 4프레임 (3배 확대)
- raw/: 원본 프레임, 기준 이미지 base_east_s12.png(시드 12). pxl.py = 호출 헬퍼(토큰은 ~/.claude.json에서 메모리로만 읽음, 저장 안 함)

## 파라미터
- 기준 캐릭터: generate-image-pixflux 64x64, no_background, view=low top-down, direction=east, outline=single color black, shading=basic, detail=medium, seed 12, 설명=신라 청년 처용(남색 긴 포, 녹색 용비늘 숄, 상투, 등에 대금, 톤 다운)
- 애니: animate-with-text 64x64(고정), reference_image=기준, view=side, direction=east, n_frames 4
  - idle: seed3 guidance6 / walk: seed5 guidance 기본(1.4) / attack: seed3 guidance6 "thrusting the flute like a short staff" / hit: seed9 guidance3.5 "knocked back..."
  - negative_description: slash effect, trails, particles, different clothes, green clothes

## 사용량
- 총 호출 약 13회(생성 13건, 각 usage generations=1.0). 402/한도 오류 없음, balance usd 0.0 그대로. 무료 플랜은 동시 1건(429 시 대기 재시도).

## 품질 평가
- 기준 이미지와 walk, idle은 캐릭터 일관성 양호, 실루엣(상투·숄·대금) 유지. 톤은 기존보다 약간 밝고 채도 높음(팔레트 정규화 필요).
- attack: 캐릭터 일관됨, 대금을 죽장처럼 쥠(색 녹색 대나무), 초승달 이펙트가 프레임에 포함(이펙트 분리 불가). 
- hit: 첫 시도 2회는 의상 붕괴/정지, 3차 시도 채택. 피격 표현 약함(프레임0은 거의 평상) - 게임에서는 백색 플래시 오버레이 병행 권장.
- idle: 거의 정지(미세 변화), 1px 바운스 합성 권장.
- 이전 시도(raw/*_0 idle/attack/hit 1차)는 의상이 녹색으로 바뀌어 폐기.

## 한계
- 애니메이션 입력이 64x64 고정 → 기존 32x48(키 36px)과 스케일 불일치. 캐릭터 키 약 50px, 게임용은 정수 다운스케일 불가(0.72배) → 재샘플/재생성 필요.
- 방향은 side(east)만 생성. 4방향(상하) 미생성(rotate/skeleton 미사용). west는 반전.
- 팔레트 미정규화, 외곽선 색 기존 #07060b와 불일치 가능. 게임 코드 연동·머지 없음.

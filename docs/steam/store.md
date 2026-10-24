# 신 처용가 — 스팀 상점 문구 (초안)

## 짧은 설명 (300자 이내)
**한국어** — 신라 헌강왕 때, 동해 용왕의 아들 처용이 역병 귀신이 휩쓴 서라벌에 닿는다. 칼 대신 노래와 춤으로 요괴의 탁기를 걷어내고, 흩어진 처용가 여덟 구절과 다섯 향가를 모아 역신을 무릎 꿇린다. 삼국유사의 설화를 따라 걷는 HD-2D 싱글 액션 RPG.

**English** — Silla, the reign of King Heongang. Cheoyong, son of the Dragon King of the East Sea, arrives in a capital ravaged by a plague spirit. He does not kill: he purifies. Gather the scattered verses of the Cheoyong-ga and five ancient hyangga, and bring the plague god to its knees. A single-player HD-2D action RPG walking through the tales of the Samguk Yusa.

## 긴 설명
### 칼이 아니라 노래로
처용은 요괴를 죽이지 않는다. 쓰러진 요괴의 탁기를 노래로 걷어 넋을 돌려보내고, 보스는 쓰러지는 대신 무릎을 꿇는다. 소매치기와 구르기, 세 가지 탈의 기술, 모은 구절만큼 강해지는 궁극기 「처용가」로 싸운다.

### 여섯 장의 순례
서라벌 저잣거리에서 시작해 남산·토함산·동해 감은사·황룡사·반월성까지. 찬기파랑가, 제망매가, 헌화가, 도천수관음가, 도솔가 — 각 장은 실제 향가 한 수와 그 노래가 지어진 사연을 따라간다.

### 탈과 부적
처용탈·귀면탈·용왕탈을 바꿔 쓰며 싸움의 결을 바꾸고, 부적으로 처용의 힘을 다듬는다.

### 특징
- 3D 지형 위의 도트 인물, 낮은 해와 긴 그림자, 구역마다 달라지는 빛과 공기
- 한국어 원작 대사(가벼운 시대극 말투), 명조체 연출
- 키보드·게임패드 지원, 자동 저장

## 태그 후보
액션 RPG, 싱글플레이어, 스토리 중심, 신화, 픽셀 그래픽, 2.5D, 판타지, 아시아 문화

## 시스템 요구 사항 (예정 — 실제 기기에서 측정 후 확정)
- OS: Windows 10 64-bit / Ubuntu 22.04 64-bit
- 그래픽: OpenGL 3.3 지원 GPU
- 메모리: 2 GB RAM
- 저장 공간: 300 MB

## 출시 전 필요한 것 (문구 외)
- Steamworks 개발자 등록과 앱 ID, 상점 페이지 심사
- 캡슐 이미지: `python3 tools/steam_art.py` → `build/steam/` (헤더 460x215, 작은 캡슐 231x87, 메인 캡슐 616x353, 세로 캡슐 374x448, 라이브러리 600x900, 라이브러리 히어로 3840x1240, 로고 1280x720)
- 스크린샷 5장 이상(1920x1080): `--nohud --capture=... --resolution 1920x1080`
- 크레딧·라이선스 고지: 게임 안 「제작진」 화면, `godot/fonts/OFL-*.txt`

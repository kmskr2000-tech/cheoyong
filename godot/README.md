# 신 처용가 — Godot 4.4 판

웹판(`src/`)과 같은 에셋·규칙을 Godot 4.4(GL Compatibility)로 옮긴 모바일 빌드.

- 실행: `godot --path godot`
- 화면 확인: `xvfb-run -a godot --rendering-driver opengl3 --path godot -- --quest=4 --at=58,50 --capture=out.png --frames=90`
- 끝까지 자동 플레이: `godot --headless --path godot -- --auto --skipintro --speed=8 --mute` (`REACHED ENDING` 출력)
- 웹 내보내기: `godot --headless --path godot --export-release Web ../build/godot-web/index.html`
- APK: `godot --headless --path godot --export-release Android ../build/cheoyong-unsigned.apk` 다음
  `java -jar ~/godot/uber-apk-signer.jar -a build/cheoyong-unsigned.apk -o build/signed`
- 클라우드 컨테이너 준비: `sh tools/setup_godot.sh` (Godot, 템플릿, 서명 도구. Android SDK 없이 비-Gradle 내보내기)
- 에셋 갱신: `python3 art/pack.py && cp -r src/assets/* godot/assets/`, 소리: `python3 art/sound.py`

## HD-2D 화면
- `scripts/view3d.gd`: 3D 지형(높이장: 구역 고도·길 완화·언덕), 물 메시, 소품 MultiMesh 빌보드, 직교 카메라(55°), 해 그림자·안개, 등불 OmniLight.
- 게임 규칙은 그대로 2D 픽셀 좌표. 캐릭터는 `Ent.draw_sprite` → 빌보드, 이름표·HP·이펙트는 `game.sp(x, y, z)`로 화면에 투영해 2D로 그린다.
- 셰이더: `billboard.gdshader`(디더 투명·흰색 깜빡임), `water.gdshader`, `tiltshift.gdshader`(위아래 흐림).

## 아이폰(웹)
- 웹 내보내기는 PWA로 나간다(홈 화면에 추가하면 전체 화면). 모바일 텍스처 압축(ETC2/ASTC)도 켰다.
- 배포: 빌드 결과만 담은 `web-play` 브랜치를 Vercel 프로젝트 `cheoyong`이 그대로 서빙한다(빌드 명령 없음) → https://cheoyong.vercel.app

## 이야기 연출
- `scripts/cine.gd`(UI의 자식 레이어): 레터박스(화면 높이 11%, 0.4초 완화), 대화창(고운바탕, 40자/초 타자, 첫 확인은 줄을 끝까지, 둘째 확인은 다음 줄), 구절·향가 배너, 구역 이름(먹 붓 밑줄), 장 제목 카드(1.2초 들어옴, 2.5초 머묾, 1.2초 나감), 지도 이동 암전(0.35초 + 0.35초).
- `scripts/typo.gd`: 자간 글자 그리기, 타자 공개, 먹 붓 획, 금빛 줄. 송명(`Assets.font_title`)은 제목·향가·구절, 고운바탕(`font_serif`)은 대사·자막, 프리텐다드는 HUD.
- 장 제목 카드 문구: 1장은 `Story.CARD1`, 2~6장은 `Chapter.card()`(장 제목과 그 장의 향가 한 줄).
- 카드·암전 중에는 세계가 멈춘다(`ui.blocking()`). `--auto`에서는 카드가 0.2배로 짧아진다.
- 훅: `--intro`, `--card=n`, `--verse=n`, `--hyangga=chan`, `--say=문장 --who=이름`.


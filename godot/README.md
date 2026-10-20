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

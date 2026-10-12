# 에셋 출처
- 지형 9종(beach/village/forest/flowerfield/shrine/mansion/palace/dungeon/underworld): 사용자 제공 AI 생성 도트 일러스트, Drive '신처용가-게임에셋/지형'(소유자=사용자). `art/terrain_import.py`로 정규화(다운스케일·56색 양자화·밤 톤·비네트·노멀맵)해 `src/assets/levels/`에 적용. 상업 이용 약관은 출시 전 사용자 확인.
- 요괴/보스 스프라이트: 사용자 소유 Google Drive 폴더 '신처용가-게임에셋/요괴'(2026-10-10 업로드 PNG 100장, 종당 idle+atk_1..3). art/yokai_import.py로 정리(불투명 검은 배경 제거, 잔재·낱알 제거, 기준선·중앙 정렬)해 8프레임 시트로 변환. 1장 적 6종+역신은 src/assets/sprites/, 2장 이후 19종은 src/assets/sprites/yokai/ (2026-10-12, 브랜치 asset/yokai).

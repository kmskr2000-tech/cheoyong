# Milestone: M1 — 1장 완성 (Vertical Slice)

## Overview

- **Target Date**: 2026-11-01
- **Type**: Vertical Slice
- **Duration**: 1주 (M0 이후)
- **Number of Sprints**: 1 (sprint-03)

## Milestone Goal

사용자가 폰에서 1장을 인트로부터 1절 완성까지 막힘 없이 끝낸다. "구현됨"을 "검증됨"으로 바꾸는 마일스톤이다. 통과하면 2장 이후는 이 슬라이스를 복제·확장하는 작업이 된다.

## Success Criteria

- [ ] 사용자 폰(iPhone Safari / Android Chrome 중 실제 쓰는 기기)에서 1장 완주 — 막힌 곳·불편 기록 (`/playtest-report`)
- [ ] 보스(역신, HP 480) 첫 도전 평균 사망 1~3회 (사용자 기록 기준으로 확정)
- [ ] 모바일 웹 30분 세션 30fps 이상, 화질 폴백(fx 2→1→0) 동작 확인 (`/perf-profile`)
- [ ] 조이스틱·부적 HUD 겹침 해소 (DEVLOG 10-09 기록 이슈)
- [ ] 음악·효과음 실제 청취 검증, 모바일 오디오 언락 확인
- [ ] 인게임 "본 게임은 설화를 재해석한 픽션입니다" 표기
- [ ] 장신구 "역신의 눈물" 효과 구현 (현재 획득만)
- [ ] 복식 결정(기획안 부록 #3) 반영 — 교체 대상 NPC 스프라이트 재생성
- [ ] S1·S2 버그 0, 콘솔 오류 0
- [ ] `/gate-check pre-production` → `/gate-check production` 판정 기록

## Feature List

### Must Ship

| Feature | Design Doc | Owner | Sprint Target | Status |
|---------|-----------|-------|--------------|--------|
| 폰 플레이테스트 1회차 + 리포트 | production/qa/playtests/ | qa-lead (+사용자) | S3 | Not Started |
| 성능 측정·화질 폴백 확인 | — | performance-analyst | S3 | Not Started |
| 터치 HUD 겹침 수정 | design/ux/ | ui-programmer, ux-designer | S3 | Not Started |
| 오디오 검증 | — | sound-designer | S3 | Not Started |

### Should Ship

| Feature | Design Doc | Owner | Sprint Target | Cut Impact | Status |
|---------|-----------|-------|--------------|-----------|--------|
| 복식 교체 (결정 시) | design/art/art-bible.md | art-director, technical-artist | S3 | 신라 기둥 위반 잔존 | Not Started |
| 역신의 눈물 효과 | design/gdd/ | systems-designer | S3 | 장신구 시스템 첫 사례 지연 | Not Started |

### Stretch Goals

| Feature | Design Doc | Owner | Value Add |
|---------|-----------|-------|----------|
| 접근성 요구사항 문서 (`design/accessibility-requirements.md`) | — | accessibility-specialist | gate-check technical-setup 요건 충족 |

## Quality Gates

| Gate | Threshold | Measurement Method |
|------|-----------|-------------------|
| 크래시율 | 0 / 세션 | 플레이테스트 |
| 프레임 | ≥30fps 모바일 | perf-profile |
| 치명 버그 | S1 0, S2 0 | bug-triage |
| 완주율 | 사용자 1/1 | playtest-report |

## Risk Register

| Risk | Probability | Impact | Mitigation | Owner | Status |
|------|------------|--------|-----------|-------|--------|
| 폰 성능 미달 (HD-2D) | 미확인 | 높음 | 화질 폴백 기본값 하향, 후처리 일부 제거 | performance-analyst | Open |
| 난이도 불일치 (봇 vs 사람) | 중 | 중 | 사용자 기록 후 보스 HP·밀도 조정 | game-designer | Open |
| 사용자 시간 부족으로 플레이테스트 지연 | 중 | 높음 | 15분 단위 구간 테스트 허용 | producer | Open |

## Dependencies

- M0 완료 (폰에서 새 빌드가 열려야 함).
- 사용자 폰 플레이.

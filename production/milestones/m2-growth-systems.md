# Milestone: M2 — 성장 시스템 완성

## Overview

- **Target Date**: 2026-11-15
- **Type**: Alpha 전반
- **Duration**: 2주
- **Number of Sprints**: 2 (sprint-04·05)

## Milestone Goal

`growth-system.md`의 미구현 항목(GROW.PIRI·MASTERY·TALISMAN_CRAFT·INCENSE·SET·ACCESSORY·스킬 8수)을 모두 동작시킨다. 2장 이후 콘텐츠가 전부 이 시스템 위에 얹히므로, 챕터 콘텐츠 전에 먼저 닫는다.

## Success Criteria

- [ ] 피리 5단계·강화 1~10(정기), 탈 6종 슬롯, 장신구 2슬롯, 세트 3종 효과 동작
- [ ] 마스터리 4종 5단계 (사용 횟수 기록·표시·효과)
- [ ] 부적 제작(화염·결박·수호)·퇴치향 6종 제작·사용(30타), 재료 드롭 계열 연결
- [ ] 스킬 28수 전부 동작 (분신·아군화·속성·상태이상·탐지 체계 포함) — 또는 부분 구현 시 사용자 승인된 컷 목록
- [ ] 각 시스템 GDD(8섹션 중 standard 요건)와 `/balance-check` 통과
- [ ] 세이브 호환: 구버전 세이브 로드 가능 또는 마이그레이션 안내
- [ ] 1장 회귀(스모크) 통과 유지

## Feature List

### Must Ship

| Feature | Design Doc | Owner | Sprint Target | Status |
|---------|-----------|-------|--------------|--------|
| 장비 시스템 (피리·탈·장신구·세트) | design/gdd/equipment.md | systems-designer, gameplay-programmer | S4 | Not Started |
| 마스터리 | design/gdd/mastery.md | systems-designer | S4 | Not Started |
| 제작 (부적·퇴치향) | design/gdd/crafting.md | economy-designer | S5 | Not Started |
| 스킬 체계 8수 | design/gdd/skill-systems.md | systems-designer, ai-programmer | S5 | Not Started |

### Should Ship

| Feature | Design Doc | Owner | Sprint Target | Cut Impact | Status |
|---------|-----------|-------|--------------|-----------|--------|
| 엔딩 분기 추적 (한풀이 누적) | design/gdd/ending-branch.md | narrative-director | S5 | 3장 분기 구현 지연 | Not Started |

### Stretch Goals

| Feature | Design Doc | Owner | Value Add |
|---------|-----------|-------|----------|
| 세이브 슬롯 확장 | — | gameplay-programmer | 후속 |

## Quality Gates

| Gate | Threshold | Measurement Method |
|------|-----------|-------------------|
| 밸런스 | 정기 수입 대비 강화 비용으로 1장→2장 사이 1~3강 가능 | `/balance-check` |
| 회귀 | 스모크 + 신규 시스템 시나리오 | smoke-check |

## Risk Register

| Risk | Probability | Impact | Mitigation | Owner | Status |
|------|------------|--------|-----------|-------|--------|
| 스킬 체계 8수가 예상보다 큼 (분신·아군화는 AI 변경) | 높음 | 중 | 먼저 `/estimate`, 필요 시 4수까지 컷하고 사용자 승인 | systems-designer | Open |
| 수치 문서(growth-system)와 실제 곡선 불일치 | 중 | 중 | GDD에 공식·예시 값 명시 후 수치 검증 | economy-designer | Open |
| 세이브 구조 변경 | 중 | 높음 | 세이브 버전 필드 추가 | gameplay-programmer | Open |

## Dependencies

- M1 완료 (밸런스 기준선이 폰 실측에 의존).
- 기획안 부록 #5(몬스터 확정), #8(채집) 결정.

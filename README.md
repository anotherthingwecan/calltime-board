# 공연 콜타임 보드

화보·공연 현장에서 **모두를 같은 시각에 부르지 않고**, 사람마다 첫 일정 N분 전에 부르는(시차 콜) 웹 도구예요.
2026-2 패션테크놀로지 중간 과제 · 임서준 · 디자인 시스템 PAPER CUE.

## 무엇이 있나요
- **NOTICE**: 무대 스태프 캐릭터 ‘큐’가 말풍선으로 공지를 말하고, 기획안 PDF를 펼쳐 보여 줘요. 내 콜 티켓, 오늘 요약.
- **CUE SHEET**: 시간순 큐시트와 멤버 목록.
- **CALL**: 줄어든 대기 시간, 역할 × 시간 표, 단톡방용 콜시트 복사.
- **CHECK-IN**: 당일 도착 체크(도착 · 대기 · 미도착).
- **ADMIN**: PD 로그인 후 공연 정보, 공지, 기획안 PDF, 큐시트, 멤버, 개인 코드 관리.

## 구조
| 부분 | 쓰는 것 |
|---|---|
| 화면 | `index.html` 한 파일 (빌드 없음) |
| 데이터 · PD 로그인 · PDF | Supabase (`supabase/schema.sql`) |
| 배포 | GitHub → Vercel 자동 배포 |

## 누가 무엇을 바꿀 수 있나요
| 사람 | 할 수 있는 것 | 막는 곳 |
|---|---|---|
| 링크를 받은 누구나 | 보기 | Supabase RLS (읽기만 허용) |
| 스태프 (개인 코드) | 내 이름 · 가능 시간 · 내 도착 체크 | 코드가 맞을 때만 동작하는 DB 함수 |
| PD (Supabase 계정) | 전부 | `pd_emails`에 있는 이메일로 로그인한 계정만 |

- 코드는 역할마다 6자리. ‘새 코드’를 누르면 이전 코드는 바로 막히고 본인 입력도 지워져요.
- Supabase anon 키는 공개용이라 `index.html`에 들어 있어도 괜찮아요. 쓰기는 DB 규칙이 막아요.

## PD를 더 추가하려면
1. Supabase → SQL Editor: `insert into public.pd_emails (email) values ('새PD@example.com');`
2. Supabase → Authentication → Users → Add user (Auto Confirm 체크)

## 수정하고 다시 배포하기
`index.html`을 고쳐서 GitHub에 올리면(commit · push) Vercel이 1분 안에 자동으로 다시 배포해요.

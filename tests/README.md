# 테스트

이 폴더의 검사들은 **`index.html` 에서 실제 코드를 떼어내** 돌린다. 테스트 안에 로직을
다시 옮겨 적으면 원본이 바뀌어도 통과해 버려서, 검사가 아니라 장식이 된다.

## 바로 돌아가는 것 (설치 필요 없음)

```bash
node tests/current-period.test.mjs     # 시간표의 '지금 이 교시' + 자정 넘김 — 가짜 시계로 확인
node tests/sw-cache.test.mjs           # 서비스워커 캐시 전략 — Cache/fetch 를 스텁으로 물림
node tests/operating.test.mjs          # 운영표(요일 대체·창체 이동·시험·휴일) 해석
node tests/account-gate.test.mjs       # 학생 계정 차단 — 화면·규칙·워커가 같은 조건인지
node tests/inline-handlers.test.mjs    # onclick 이 부르는 함수가 window 에 있는지
node tests/widget-config.test.mjs      # 위젯이 설정 폴더를 만들고 쓰는지(.ahk 원본 확인)
node workers/teacher-api.test.mjs      # teacher-api 워커 — fetch 를 스텁으로 물림
```

> `workers/roster-split.test.mjs` · `workers/parent-verify.test.mjs` 는 `upload.html` 을
> 읽으므로 **test 저장소에서만** 돈다. 이 저장소에는 그 파일이 없다.

## 설치가 필요한 것

```bash
npm i -D playwright @firebase/rules-unit-testing firebase firebase-tools
```

### 외출증 화면 (Chromium)

```bash
python3 tests/build-pass-harness.py /tmp/ph.html   # index.html 에서 코드·마크업·CSS 추출
PASS_HARNESS=/tmp/ph.html node tests/pass-ui.test.mjs
```

FAB(모바일 발급 버튼)은 `#passPage` 바깥의 `position:fixed` 라 하네스가 아니라
따로 본다. 설치만 되어 있으면 바로 돌아간다.

```bash
node tests/pass-fab.test.mjs                       # FAB 이 외출증 화면에서만 뜨는지
node tests/cal-consult.test.mjs                    # 업무 캘린더의 상담 예약 표시·상세
node tests/consult-weekend.test.mjs                # 상담 주말 슬롯 + 7칸 폭 측정
node tests/task-share.test.mjs                     # 공유받은 업무에 작성자·함께 받은 사람
node tests/seat-inpage.test.mjs                    # 자리 배치 '크게 보기' → 앱 안 화면 + 돌아가기
```

### 교실 자리 배치 (seating.html)

자리 배치는 눈으로 보면 그럴듯한데 제약 하나가 조용히 깨져 있어도 모른다.
그래서 배정 결과를 값으로 확인한다.

```bash
node tests/seating.test.mjs        # 배정이 제약(고정·앞자리·분리)을 실제로 지키는지
node tests/seating-page.test.mjs   # 실제 브라우저 — 표에서 켜고 끄기, 끌어놓기, 화면 폭
node tests/seating-print.test.mjs  # 9가지 분단·줄 조합이 모두 A4 한 장인지
```

가짜 Firestore를 물려 목록 렌더·사진 표시·발급 폼·저장 payload를 실제 DOM에서 본다.

### 보안 규칙 (Firestore 에뮬레이터)

에뮬레이터를 먼저 띄운다. `firebase.json` 에 포트를 지정해 두고:

```bash
npx firebase emulators:start --only firestore    # 기본 8099 로 맞춰 둘 것
node tests/pass-rules.test.mjs                   # 외출증 규칙
```

> 에뮬레이터가 거부된 쓰기마다 `evaluation error` 를 함께 찍는다. 규칙이
> `resource.data.…` 를 참조하는 거부 사례에서만 나오고 **결과는 항상 의도대로**다
> (거부는 거부, 허용은 허용). 원인을 끝까지 규명하지 못했으니 이 줄이 보인다고
> 규칙이 깨진 것으로 오해하지 말 것 — 판단은 통과/실패 집계로 한다.

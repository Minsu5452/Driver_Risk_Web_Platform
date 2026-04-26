# Driver Risk Web Platform — 배포 가이드

외부망 분리 환경에 배포하기 위한 포터블 zip 패키지 생성 및 설치 절차입니다.

---

## 1. 배포 zip 생성 (개발자, Mac에서 실행)

`deploy/build-package.sh`가 다음을 한 번에 수행합니다.

1. 이전 검증된 zip의 `python/`, `jre/`, `nginx/`, `wheels/` 번들을 템플릿으로 사용
2. `frontend` 를 `npm run build`로 새로 빌드 → `frontend/dist/`
3. `backend` 를 `mvn package`로 새로 빌드 → `nia-platform.jar`
4. `ai-engine/src/` 최신 소스 복사, `requirements.txt`는 `pyproject.toml`에서 재생성
5. `deploy/scripts/` 의 install/start/stop.bat 을 루트에 복사 (BOM 제거, CRLF 정리)
6. `deploy/nginx/nginx.conf` 를 `nginx/conf/nginx.conf`로 교체
7. 새 zip 생성: `dist/NIA-Platform-AutoStart.zip`

```bash
# 기본 템플릿 경로 사용
./deploy/build-package.sh

# 템플릿/출력 경로 직접 지정
./deploy/build-package.sh /path/to/template.zip /path/to/output.zip
```

> 기본 템플릿 경로는 본인 로컬에만 존재했으며, 공개 데모 빌드에는 포함되지 않습니다. (외부망 분리 환경 운영 빌드 전용)

---

## 2. 보안 검사 및 메일 전송

생성된 `dist/NIA-Platform-AutoStart.zip` (약 500MB) 을 메일로 보내 보안 검사를 받습니다.

---

## 3. 설치 (운영 Windows PC, 관리자 권한)

### 3-1. 압축 해제

zip 을 **영문/공백 없는 경로**에 해제합니다. 예) `D:\temp\NIA-Platform-AutoStart\`

> **주의**: `C:\Users\홍길동\바탕 화면\` 같은 한글/공백 경로는 절대 사용하지 말 것.

### 3-2. install.bat 실행

`NIA-Platform-AutoStart\install.bat` 을 **마우스 우클릭 → 관리자 권한으로 실행**.

`install.bat` 이 자동으로 수행하는 작업:

| 단계 | 내용 |
|---|---|
| A | 기존 `NIA_Platform` 자동시작 태스크 해제 |
| B | 실행 중인 NIA 서비스 종료 (경로 필터 + 포트 3000/8000/8080 이중 확인) |
| C | `C:\NIA-Platform` 삭제 (재시도 5회, 최대 50초 대기) |
| D | 새 파일 복사 |
| E | Python embeddable 설정 (`python310._pth` 수정) |
| F | pip 오프라인 설치 (`wheels/`) |
| G | AI Engine 의존성 오프라인 설치 |
| H | 방화벽 규칙 / 바탕화면 바로가기 / 자동시작 태스크 등록 |
| I | `start.bat` 호출 → 서비스 기동 |

설치 완료 후 브라우저가 `http://localhost:3000` 으로 자동 열립니다.

---

## 4. 관리자 계정

| 항목 | 값 |
|---|---|
| 사용자명 | `admin` |
| 비밀번호 | `change-me-in-prod` (예시값 — 운영 배포 시 반드시 교체) |

`start.bat` 이 환경변수로 주입하므로 설정 파일 수정 불필요.

> ⚠️ 본 데모 저장소에 노출된 자격증명은 **placeholder** 입니다. 실제 운영 빌드에서는 별도 채널로 전달된 운영 비밀번호를 사용하세요.

---

## 5. 일상 운영

| 작업 | 방법 |
|---|---|
| 시작 | 바탕화면 **NIA Start** 더블클릭 (또는 `C:\NIA-Platform\start.bat`) |
| 종료 | 바탕화면 **NIA Stop** 더블클릭 (또는 `C:\NIA-Platform\stop.bat`) |
| 접속 | 바탕화면 **NIA Platform** 더블클릭 (또는 `http://localhost:3000`) |
| 자동 시작 | Windows 로그인 시 `schtasks` 가 `start.bat` 을 자동 실행 |

---

## 6. 데이터 / 로그 위치

```
C:\NIA-Platform\
├── ai-engine\data\       AI Engine DB (검사 기록 등)
├── ai-engine\artifacts\  학습된 모델 (versions/)
└── logs\
    ├── ai-engine.log         / ai-engine-error.log
    ├── backend.log           / backend-error.log
    ├── nginx-access.log      / nginx-error.log
    ├── install-pip.log       / install-packages.log
```

재배포 시 `install.bat` 은 `C:\NIA-Platform` 을 **통째로 삭제**합니다. 즉 DB/모델도 초기화됩니다 (매 배포 시 모델 재학습 전제).

---

## 7. 문제 해결

### "관리자 권한으로 실행하세요" 에러
→ install.bat 우클릭 → **관리자 권한으로 실행**.

### "Cannot remove old installation" 에러
→ `C:\NIA-Platform` 을 연 상태인 탐색기/에디터/터미널을 모두 닫은 뒤 재시도.

### "pip install failed" 에러
→ `C:\NIA-Platform\logs\install-pip.log` 확인. 대부분 wheels 누락 → 템플릿 zip 재수령 필요.

### 관리자 로그인 실패
→ `start.bat` 을 해당 계정 환경이 아닌 다른 경로에서 실행했거나, 이전 설치의 start.bat이 실행 중일 수 있음. `stop.bat` 후 `start.bat` 재실행.

### 포트 충돌 (3000/8000/8080)
→ `install.bat` 이 기존 점유자를 종료하지만, 안 될 경우 수동으로:
```
netstat -ano | findstr :3000
taskkill /PID <번호> /F
```

### 한글 깨짐
- 업로드 파일명 한글: 정상 처리됨 (FastAPI UTF-8)
- 서버 응답 한글: `application.properties` UTF-8 강제 + JVM `-Dfile.encoding=UTF-8` 적용됨
- 콘솔 출력 한글: `chcp 65001` + `PYTHONUTF8=1` 적용됨
- 폴더 경로에 한글 포함 시: **설치 경로를 반드시 `C:\NIA-Platform` 으로만 유지**

---

## 8. 재배포 (업데이트)

1. 개발자: `./deploy/build-package.sh` → 새 `NIA-Platform-AutoStart.zip`
2. 보안 검사 → 운영 PC 전달
3. 운영자: 압축 해제 → **install.bat 관리자 권한 실행**
4. `install.bat` 이 기존 설치를 자동으로 정리하고 새 버전으로 덮어씁니다.

# 운수종사자 사고 위험 예측 웹 플랫폼 설치 가이드

이 문서는 사전에 빌드된 Windows 포터블 패키지를 설치하고 실행하는 방법을 정리한 운영자용 가이드입니다.

## 사전 조건

- Windows 10 64-bit 이상
- 최초 설치 시 관리자 권한 필요
- 디스크 여유 공간 2GB 이상
- zip 압축 해제 경로에는 한글과 공백이 없는 것을 권장합니다. 예: `D:\temp\`, `C:\install\`

설치 스크립트는 runtime 파일을 `C:\NIA-Platform`으로 복사합니다. 이 경로는 기존 batch script와의 호환성을 위해 유지합니다.

## 설치

1. zip 파일을 압축 해제합니다.
2. 압축 해제된 패키지 폴더로 이동합니다.
3. `install.bat`을 우클릭한 뒤 관리자 권한으로 실행합니다.
4. 파일 복사, offline Python package 설치, 방화벽 규칙 등록, 바탕화면 바로가기 생성, 자동 시작 등록, 서비스 실행이 순서대로 진행됩니다.
5. 브라우저가 자동으로 열리지 않으면 `http://localhost:3000`에 접속합니다.

## 관리자 계정

관리자 계정은 runtime의 `admin.conf` 또는 환경변수로 전달합니다.

```text
username=<admin-id>
password=<admin-password>
```

운영 계정 정보는 저장소나 공개 배포 가이드에 직접 적지 않습니다.

## 일상 운영

| 작업 | 방법 |
| --- | --- |
| 시작 | 바탕화면 `NIA Start` 또는 `C:\NIA-Platform\start.bat` |
| 종료 | 바탕화면 `NIA Stop` 또는 `C:\NIA-Platform\stop.bat` |
| 접속 | 바탕화면 `NIA Platform` 또는 `http://localhost:3000` |
| 자동 시작 | Windows 로그인 후 scheduled task로 실행 |

## 데이터와 로그

```text
C:\NIA-Platform\
├── VERSION
├── ai-engine\data\
├── ai-engine\artifacts\
└── logs\
    ├── ai-engine.log
    ├── backend.log
    ├── nginx-access.log
    └── nginx-error.log
```

재설치 과정에서는 batch script 버전에 따라 로컬 DB, 업로드 파일, 학습 모델이 삭제될 수 있습니다. 필요한 runtime 데이터는 재설치 전에 별도로 백업합니다.

## 문제 해결

| 증상 | 확인할 내용 |
| --- | --- |
| 관리자 권한 경고 | `install.bat`을 관리자 권한으로 다시 실행 |
| 브라우저 접속 실패 | `NIA Stop` 후 `NIA Start` 실행, 로그 확인 |
| 포트 충돌 | `3000`, `8000`, `8080` 포트 점유 여부 확인 |
| 한글 표시 문제 | 브라우저 새로고침과 서버 로그의 UTF-8 설정 확인 |
| 기존 설치 파일 교체 실패 | `C:\NIA-Platform`을 열고 있는 탐색기, 에디터, 터미널 종료 |

## 제거

1. `NIA Stop`을 실행합니다.
2. 필요하면 관리자 shell에서 scheduled task와 firewall rule을 삭제합니다.
3. 필요한 runtime 데이터를 백업한 뒤 `C:\NIA-Platform`을 삭제합니다.

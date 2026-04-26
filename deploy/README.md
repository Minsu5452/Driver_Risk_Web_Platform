# 배포 메모

이 디렉터리는 운수종사자 사고 위험 예측 웹 플랫폼을 Windows 포터블 패키지로 만들기 위한 빌드 스크립트와 실행 스크립트를 보관합니다.

## 패키지 생성

`deploy/build-package.sh`는 현재 프론트엔드와 백엔드를 새로 빌드하고, AI 엔진 최신 소스를 반영한 뒤, 검증된 Windows runtime template 위에 다시 압축합니다.

```bash
./deploy/build-package.sh
./deploy/build-package.sh /path/to/template.zip /path/to/output.zip
```

스크립트 안의 기본 template 경로는 기존 로컬 환경 기준입니다. 다른 환경에서 빌드할 때는 template zip과 output zip 경로를 명시해서 실행합니다.

## 빌드 과정

1. Python, JRE, Nginx, offline wheels가 들어 있는 template bundle을 압축 해제합니다.
2. `frontend`를 `npm run build`로 빌드합니다.
3. `backend`를 Maven으로 빌드하고 생성된 JAR를 복사합니다.
4. `ai-engine/src/`를 복사하되 로컬 데이터, 로그, 환경 파일, cache, 모델 산출물은 제외합니다.
5. `install.bat`, `start.bat`, `stop.bat`, `autostart-task.xml`, `nginx.conf`를 반영합니다.
6. `dist/` 아래에 versioned zip을 생성합니다.
7. 출력 zip 안에 개발 산출물이나 민감 파일이 섞였는지 검사합니다.

## 설치 경로

Windows 스크립트는 기존 배포 bundle과의 호환성을 위해 `C:\NIA-Platform` 경로를 사용합니다. 경로명을 바꾸려면 batch script와 scheduled-task XML을 함께 수정해야 합니다.

```text
C:\NIA-Platform\
├── ai-engine\
├── backend\
├── frontend\
├── nginx\
└── logs\
```

## 자격증명과 데이터

실제 계정 정보는 저장소에 저장하지 않습니다. AI 엔진은 runtime에서 `admin.conf` 또는 환경변수로 관리자 계정을 읽습니다. 업로드 데이터, 생성 DB, 학습 모델, 배포 zip 산출물은 공개 저장소에서 제외합니다.

## 운영자 가이드

`INSTALL.md`는 패키지 생성 시 운영자용 `README.md`로 복사됩니다.

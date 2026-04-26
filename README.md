# 운수종사자 교통사고 위험 예측 모델·관리 웹 개발

운수종사자 검사 데이터와 사고 이력을 바탕으로 교통사고 위험도를 예측하고, 그 결과를 대시보드·개별 진단·관리자 화면에서 확인할 수 있도록 만든 풀스택 관리 웹 데모입니다.

## 개요

| 항목 | 내용 |
| --- | --- |
| 분야 | 교통 안전 위험 예측 |
| 범위 | 프론트엔드, 백엔드, AI 엔진, 배포 스크립트 |
| 역할 | 단독 개발 |
| 기술 | React, Vite, Mantine, Spring Boot/eGovFrame, FastAPI, LightGBM, XGBoost, CatBoost, SHAP, Nginx |
| 실행 환경 | 로컬 개발 환경, Windows 포터블 배포 패키지 |

## 주요 기능

- 운수종사자 검사 데이터 업로드, 전처리, 예측, 개별 이력 조회를 처리합니다.
- 위험도 대시보드, 운전자 목록, 개별 진단 리포트, 데이터 다운로드 화면을 제공합니다.
- FastAPI AI 엔진에서 학습, 추론, SHAP 설명, 모델 버전 관리를 담당합니다.
- Spring Boot/eGovFrame 백엔드는 공공기관 스타일의 로그인, 게시판, 파일, 공통 API 구조를 담당합니다.
- Nginx와 Windows batch script를 통해 외부망 분리 환경에서도 포터블 패키지로 실행할 수 있게 구성했습니다.

## 구조

```text
브라우저
  |
  v
Nginx 또는 Vite proxy
  |-- /api/predict/*  -> FastAPI AI Engine
  |-- /api/analysis/* -> FastAPI AI Engine
  |-- /api/admin/*    -> FastAPI AI Engine
  `-- /api/*          -> Spring Boot 백엔드
```

## 저장소 구성

```text
.
├── ai-engine/          # FastAPI 기반 ML 서비스
│   ├── src/api/        # upload, predict, explain, admin API
│   ├── src/data/       # 데이터 로딩, 전처리, 피처 변환
│   ├── src/inference/  # rank1 / rank7 추론 엔진
│   ├── src/training/   # 학습 파이프라인
│   └── src/services/   # 예측 / 학습 서비스 계층
├── backend/            # Spring Boot + eGovFrame 백엔드
├── frontend/           # React + Vite 프론트엔드
├── deploy/             # Nginx 설정과 Windows 배포 스크립트
├── Makefile
└── VERSION
```

## 모델 흐름

- A/B 검사 도메인을 분리한 tree ensemble 계열 모델과 시퀀스 피처를 활용한 통합 모델을 함께 다룹니다.
- 검사 이력, 사고 이력, 시퀀스 통계, 반응시간·정확도 기반 파생 변수를 활용합니다.
- SHAP 기반 개별 설명과 전역 중요도를 제공해 예측 결과를 검토할 수 있게 했습니다.
- 업로드 데이터와 학습된 모델 버전은 AI 엔진의 DB에서 추적합니다.

## 로컬 실행

필요한 도구:

- Python 3.10 + `uv`
- Node.js 20+
- Java 8 JDK, Maven

```bash
make install-ai
make install-frontend

make dev-ai        # http://localhost:8000
make dev-frontend  # http://localhost:3000
make dev-backend   # http://localhost:8080
```

관리자 계정은 `admin.conf`, 환경변수, 또는 AI 엔진 fallback 값에서 읽습니다. 실제 계정 정보는 커밋하지 않습니다.

## 공개 범위

공개 저장소에는 코드 구조와 데모 실행 흐름만 남겼습니다. 원본 데이터, 업로드 파일, 학습된 모델, 로컬 DB, 운영 자격증명, 배포 zip 산출물은 `.gitignore`로 제외합니다.

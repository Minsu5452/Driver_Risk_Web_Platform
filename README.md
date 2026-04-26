# Driver Risk Web Platform

> 운수종사자(버스·택시·화물 등)의 **자격유지검사 / 신규검사** 결과와 과거 사고 이력을 분석해
> 향후 교통사고 발생 위험도를 예측·시각화하는 **풀스택 웹 플랫폼** 데모 버전.

---

## ⚠️ 공개 범위 (Disclaimer)

본 저장소는 **한국지능정보사회진흥원(NIA)** 가 관리하고 **한국교통안전공단**이 발주처인
"AI 기반 교통안전 위험태세 예측 플랫폼" 사업을 데이콘이 수행한 결과물 중,
**본인이 입사 후 단독으로 디벨롭한 코드를 데모 형태로 정리한 것**입니다.

- 발주처가 운영한 **데이콘 경진대회 상위권 솔루션 (Rank1·Rank7 앙상블)** 을 출발점으로 삼아,
  본인이 풀스택 웹 플랫폼 (Frontend / Backend / AI Engine / 배포 자동화) 까지 단독 구현했습니다.
- 발주처 식별 정보(연락처·이메일·운영 자격증명)는 **마스킹** 되어 있습니다.
  실제 운영 빌드에서는 환경변수 / 별도 채널로 주입된 값을 사용했습니다.
- 데이터(`경진대회데이터/`, `샘플데이터/`)와 학습된 모델 가중치(`ai-engine/artifacts/`)는
  본 저장소에 포함되지 않습니다 (gitignored). 코드 흐름과 아키텍처만 공개합니다.
- 본 저장소는 **공개 데모 빌드** 입니다. 실 운영 자산이 아닙니다.

---

## 본인 작업 범위

본인 단독 개발 (입사 후) — 기획 · 데이터 파이프라인 · 모델링 · 프론트엔드 · 백엔드 · 배포 자동화 전반.

| 레이어 | 본인이 한 일 |
|---|---|
| 모델링 | 경진대회 Rank1(A/B 도메인 분리 stacking) · Rank7(시퀀스 피처 단일 모델) 솔루션을 실 배포 가능한 추론 파이프라인으로 재구성 |
| AI Engine | FastAPI 서비스화 · SHAP 개별/전역 설명 · 학습/추론 분리 · 버전 관리 |
| Frontend | React SPA (대시보드, 운전자 목록, 개별 정밀 진단, 관리자) |
| Backend | Spring Boot + eGovFrame 기반 인증/세션/공통 API |
| 배포 | Windows 외부망 분리 환경 대응 — 포터블 zip + nginx + 자동시작 등록 + 오프라인 wheel 설치 |

---

## 시스템 아키텍처

```
 ┌──────────────┐
 │   Browser    │
 └──────┬───────┘
        │ http://localhost:3000
        ▼
 ┌──────────────┐    /                 → frontend/dist (React SPA)
 │    Nginx     │    /api/admin/*      → AI Engine /admin/*
 │  (port 3000) │    /api/analysis/*   → AI Engine /*
 └──┬────────┬──┘    /api/predict/*    → AI Engine /predict/*
    │        │       /api/*            → Spring Boot /api/*
    ▼        ▼
 ┌──────┐  ┌──────────┐
 │ AI   │  │ Spring   │
 │Engine│  │ Boot     │
 │:8000 │  │ :8080    │
 └──────┘  └──────────┘
```

**프록시 규칙은 구체적 경로가 먼저** 매칭됩니다 (`/api/admin` > `/api/analysis` > `/api/predict` > `/api`).
Nginx(`deploy/nginx/nginx.conf`) 와 Vite(`frontend/vite.config.js`) 가 동일 규칙을 따릅니다.

---

## 기술 스택

| 레이어 | 기술 |
|---|---|
| Frontend | React 18, Vite 5, Mantine UI 8, Zustand, Recharts, react-router |
| Backend (eGov) | Spring Boot 2.7 + eGovFrame 4.3, Java 8, HSQL(인메모리) |
| AI Engine | FastAPI, Python 3.10, scikit-learn, LightGBM, XGBoost, CatBoost, SHAP |
| Runtime | Windows 포터블 (embeddable Python / JRE / Nginx) |

---

## 디렉토리 구조

```
Driver_Risk_Web_Platform/
├── ai-engine/                FastAPI + ML (port 8000)
│   ├── src/
│   │   ├── api/              업로드/예측/관리자 엔드포인트
│   │   ├── core/             DB, 상수, 분석 캐시
│   │   ├── data/             전처리/변환
│   │   ├── inference/        추론 엔진 (rank1, rank7)
│   │   ├── training/         학습 엔진 (rank1_trainer, rank7_trainer)
│   │   ├── models/           앙상블 정의
│   │   ├── services/         prediction_service, training_service
│   │   ├── utils/            공통 유틸 (age_calc, optimization_utils)
│   │   ├── main.py           FastAPI 엔트리
│   │   └── schemas.py        Pydantic 스키마
│   ├── pyproject.toml        Python 의존성 (uv 관리)
│   ├── data/                 (gitignored) 업로드, DB 파일
│   └── artifacts/versions/   (gitignored) 학습된 모델
│
├── backend/                  Spring Boot + eGovFrame (port 8080)
│   ├── src/main/java/egovframework/...
│   ├── src/main/resources/
│   │   ├── application.properties         UTF-8 강제 설정 포함
│   │   └── application-prod.properties
│   └── pom.xml
│
├── frontend/                 React + Vite (port 3000)
│   ├── src/
│   │   ├── pages/nia/        분석/대시보드/정밀진단
│   │   ├── pages/admin/      관리자 대시보드
│   │   ├── components/
│   │   ├── store/            Zustand (sessionStorage persist)
│   │   ├── constants/site.js 발주처 식별 텍스트 (본 데모는 마스킹)
│   │   └── utils/
│   ├── package.json
│   └── vite.config.js
│
├── deploy/                   배포 zip 빌드 & Windows 스크립트
│   ├── build-package.sh
│   ├── scripts/              install.bat / start.bat / stop.bat
│   ├── nginx/nginx.conf
│   ├── README.md             운영자용 배포 가이드
│   └── INSTALL.md
│
├── Makefile                  개발 서버 실행 단축 명령
├── CLAUDE.md
└── README.md                 (이 파일)
```

---

## 개발 환경 셋업 (Mac/Linux)

### 사전 요구사항
- Python 3.10 (+ [`uv`](https://github.com/astral-sh/uv))
- Node.js 20+, npm
- Java 8 JDK, Maven 3.9+

### 의존성 설치
```bash
make install-ai          # ai-engine uv sync
make install-frontend    # frontend npm install
# backend: mvn 이 첫 실행 시 자동 의존성 다운로드
```

### 서비스 실행 (3개 모두 병렬 기동)
```bash
make dev-ai        # AI Engine  — http://localhost:8000
make dev-frontend  # Frontend   — http://localhost:3000
make dev-backend   # Backend    — http://localhost:8080
```

브라우저에서 http://localhost:3000 접속.

### 관리자 로그인 (데모 빌드)
- ID: `admin`
- PW: 로컬 개발 기본값 `1` / `start.bat` 의 환경변수 placeholder `change-me-in-prod`
- 운영 빌드는 별도 채널로 전달된 비밀번호를 환경변수로 주입했습니다 (본 데모에는 포함되지 않습니다).

---

## 주요 API

### AI Engine (`http://localhost:8000`)
| Method | Path | 설명 |
|---|---|---|
| POST | `/predict` | 단건/배치 예측 |
| GET | `/predict/history/{primary_key}` | 특정인 검사 이력 |
| POST | `/predict/explain` | SHAP 개별 설명 |
| GET | `/predict/explain_global` | SHAP 전역 설명 |
| POST | `/upload/{domain}` | 검사 데이터 업로드 (domain: `a`, `b`, `sago`) |
| GET | `/admin/training/status` | 학습 진행 상태 |
| POST | `/admin/training/start` | 모델 재학습 시작 |
| POST | `/admin/training/cancel` | 학습 취소 |

### Backend (`http://localhost:8080`)
Spring Boot + eGovFrame 기반 게시판/로그인/파일 관리 공통 API. 프론트엔드는 `/api/*` (구체 경로 매칭 실패 시) 로 접근.

---

## 데이터 형식

### 3개 도메인
| 도메인 | 설명 | 식별자 |
|---|---|---|
| `A` | 신규검사 | PrimaryKey + 검사일 |
| `B` | 자격유지검사 | PrimaryKey + 검사일 |
| `sago` | 과거 사고 이력 | PrimaryKey + AccDate |

### PrimaryKey
업로드 파일의 `주민번호_hash` 컬럼에서 `0x` 접두어 제거 + 소문자화 (`resolve_pk()` — `ai-engine/src/api/upload.py`).
사람 단위 식별자로 프론트엔드 탐색/중복 제거의 기준.

### Age 코드
`"30a"` = 30~34세 (초반), `"30b"` = 35~39세 (후반). `parseInt()` 금지, 반드시 `parseAgeCode()` 사용.

### Excel 읽기
모든 `pd.read_excel()` 호출에 `dtype=str` 필수. 미적용 시 앞자리 0 손실 등 데이터 훼손 발생.

---

## 모델

### Rank1 (1등 솔루션 기반)
- A 도메인 (신규검사) / B 도메인 (자격유지검사) 각각 별도 앙상블
- LightGBM + XGBoost + CatBoost + scikit-learn Stacking

### Rank7 (7등 솔루션 기반)
- 도메인 통합 단일 모델
- 시퀀스 피처 (A6-1~A9-5, B9-1~B10-6) 활용

### 학습 결과 (배포 시점 v_1 기준)
- Rank1 A AUC ≈ 0.728, Rank1 B AUC ≈ 0.727
- Rank7 AUC ≈ 0.742
- 학습 소요: 약 44분

> 위 수치는 본인 환경에서 재현한 참고 값입니다. 실제 운영 데이터와는 다를 수 있습니다.

### 버전 관리
`ai-engine/artifacts/versions/v_{run_id}/` 에 저장. 활성 버전은 DB (`admin.db`) 에서 추적하며
`get_active_model_dir()` 로 조회 (`core/constants.py`).

---

## 주요 성능 지표

| 지표 | 방향 | 설명 |
|---|---|---|
| Score | ↓ 낮을수록 | 대회 공식 스코어 (log loss 기반) |
| AUC | ↑ 높을수록 | ROC-AUC. 이진 분류 성능 |
| Brier | ↓ 낮을수록 | 확률 예측 정확도 |
| ECE | ↓ 낮을수록 | 보정 오차 (Expected Calibration Error) |
| MCC | ↑ 높을수록 | Matthews 상관계수 |

---

## 배포 (요약)

본 데모 저장소는 **외부망 분리 환경 운영 빌드 (Windows 포터블 zip)** 의 빌드 스크립트와 설치 스크립트만 포함하며,
실제 운영용 zip 본체와 발주처 운영 자격증명은 포함하지 않습니다.

상세는 [`deploy/README.md`](deploy/README.md), [`deploy/INSTALL.md`](deploy/INSTALL.md) 참조.

---

## 마스킹 / 제외 항목 (본 공개 데모)

- ❌ 발주처 식별 연락처/이메일 (`frontend/src/constants/site.js` 의 `CONTACT_EMAIL`, `CONTACT_PHONE`)
  → placeholder 로 치환 (`contact@example.com`, `000-000-0000`)
- ❌ 운영 관리자 비밀번호 → `change-me-in-prod` 로 치환
- ❌ 운영 빌드 zip 템플릿 경로 (본인 로컬 절대경로) → 안내 문장으로 치환
- ❌ 학습/추론 데이터 (`경진대회데이터/`, `샘플데이터/`)
- ❌ 학습된 모델 가중치 (`ai-engine/artifacts/`)
- ❌ 운영 zip 산출물 (`dist/`, `frontend/dist/`, `backend/target/`)
- ❌ 기존 commit 히스토리 (마스킹 전 문자열 보호 위해 새 git 으로 재초기화)

---

## 제작

**강민수** · 데이콘 DS팀

기획 · 데이터 파이프라인 · 모델링 · 프론트엔드 · 백엔드 · 배포 전반 단독 개발.

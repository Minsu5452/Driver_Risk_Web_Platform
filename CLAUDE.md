# Driver Risk Web Platform — Claude Code 지침

## 프로젝트 구동 규칙
사용자가 "프로젝트 구동", "프로젝트 시작", "서버 띄워줘" 등으로 요청하면 **반드시 3개 서비스를 모두 백그라운드로 기동**한다.

```bash
make dev-ai        # AI Engine  — port 8000 (FastAPI + Python ML)
make dev-frontend  # Frontend   — port 3000 (React + Vite + Mantine)
make dev-backend   # Backend    — port 8080 (Spring Boot eGov)
```

- 세 명령은 독립적이므로 **한 메시지에서 병렬 `run_in_background: true`** 로 실행한다.
- 기동 후 `sleep` 뒤 각 로그를 `tail`로 확인해 에러 없이 올라왔는지 검증한다.
- 일부만 띄우려면 사용자가 명시적으로 요청할 때만 선택적으로 기동한다.

# Final Exam - CI/CD Pipeline with Docker and SonarQube for FastAPI

Dự án này đáp ứng đầy đủ yêu cầu đề bài: container hóa FastAPI bằng Docker multi-stage build, chạy lint/test/coverage, tích hợp SonarQube Quality Gate, build/push Docker image và deploy Blue-Green với health check + rollback.

## 1. Kiến trúc thư mục

```text
.
├── app/                          # FastAPI source code
├── tests/                        # Pytest unit tests
├── .github/workflows/ci-cd.yml   # CI/CD pipeline GitHub Actions
├── deploy/                       # Blue-Green deployment scripts + Nginx config
├── docs/                         # Answers and submission checklist
├── Dockerfile                    # Multi-stage production Dockerfile
├── .dockerignore                 # Reduce build context and final image noise
├── docker-compose.sonar.yml      # Local SonarQube server
├── docker-compose.bluegreen.yml  # Local Blue-Green deployment stack
├── sonar-project.properties      # SonarQube project config
├── pyproject.toml                # Ruff, pytest, coverage config
├── requirements.txt              # Runtime dependencies
└── requirements-dev.txt          # Dev/test/lint dependencies
```

## 2. Chạy local

Yêu cầu: Python 3.11+, Docker, Docker Compose.

```bash
python3 -m venv .venv
source .venv/bin/activate
make install
make lint
make test
```

Chạy app local:

```bash
uvicorn app.main:app --reload
curl http://127.0.0.1:8000/health
```

## 3. Build và chạy Docker image

```bash
make docker-build IMAGE_TAG=local
make docker-run IMAGE_TAG=local
curl http://127.0.0.1:8000/health
```

Dockerfile đã có:

- Multi-stage build
- Python 3.11 slim runtime image
- Non-root user `app`
- `.dockerignore`
- `HEALTHCHECK` gọi `/health`
- Không copy test/dev files vào runtime image

## 4. Chạy SonarQube local

Khởi động SonarQube:

```bash
make sonar-up
```

Mở SonarQube ở `http://localhost:9000`, đăng nhập mặc định `admin/admin`, đổi password, tạo project token và export token:

```bash
export SONAR_TOKEN="your-token-here"
make sonar-scan
```

Trên Linux, nếu container scanner không truy cập được `host.docker.internal`, chạy:

```bash
SONAR_HOST_URL=http://172.17.0.1:9000 make sonar-scan
```

## 5. GitHub Actions CI/CD

Pipeline nằm ở `.github/workflows/ci-cd.yml`.

Các stage chính:

1. `lint`: chạy Ruff.
2. `test`: chạy pytest và tạo `coverage.xml`.
3. `sonarqube`: scan source code, gửi coverage vào SonarQube, chờ Quality Gate.
4. `build`: build và push Docker image lên GHCR khi push vào `main`.
5. `deploy`: self-hosted runner pull image và chạy Blue-Green deployment.

Cần cấu hình GitHub Secrets:

| Secret | Ý nghĩa |
|---|---|
| `SONAR_TOKEN` | Token của SonarQube project |
| `SONAR_HOST_URL` | URL SonarQube, ví dụ `http://your-server:9000` |

Nếu dùng GHCR trong cùng repository, `GITHUB_TOKEN` mặc định có thể dùng để push/pull package khi workflow có quyền `packages: write/read`.

## 6. Blue-Green deployment local

Build image version đầu tiên:

```bash
docker build -t fastapi-devops-pipeline:v1 .
IMAGE_NAME=fastapi-devops-pipeline IMAGE_TAG=v1 ./deploy/blue-green-deploy.sh v1
curl http://127.0.0.1:8080/health
```

Deploy version mới:

```bash
docker build -t fastapi-devops-pipeline:v2 .
IMAGE_NAME=fastapi-devops-pipeline IMAGE_TAG=v2 ./deploy/blue-green-deploy.sh v2
curl http://127.0.0.1:8080/health
```

Rollback:

```bash
./deploy/rollback.sh
curl http://127.0.0.1:8080/health
```

Cách hoạt động:

- Nếu traffic đang ở blue, script deploy version mới sang green.
- Script đợi container green healthy.
- Nginx reload config để chuyển traffic sang green.
- Container blue vẫn có thể giữ lại để rollback nhanh.
- Nếu health check fail, script dừng trước khi switch traffic.

## 7. Cách nộp bài

Nên nộp toàn bộ repository này, kèm ảnh chụp hoặc log chứng minh:

- `make lint` pass
- `make test` pass và coverage đạt yêu cầu
- Docker image build thành công
- SonarQube Quality Gate pass
- GitHub Actions pipeline pass
- Blue-Green deploy switch traffic thành công
- Rollback script hoạt động

Phần trả lời lý thuyết nằm trong `docs/answers.md`.


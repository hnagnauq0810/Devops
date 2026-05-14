## 1. Explain why multi-stage builds are used in the Dockerfile and how they improve both image size and security

Multi-stage build tách quá trình build dependency ra khỏi image runtime. Ở stage `builder`, Docker cài các công cụ nặng như compiler, build-essential, pip cache và tạo virtual environment. Ở stage `runtime`, image chỉ copy `/opt/venv` và source code cần chạy ứng dụng.

Lợi ích chính:

- **Giảm kích thước image**: runtime image không chứa build tools, cache, test files, `.git`, tài liệu hoặc dependency dev.
- **Tăng bảo mật**: image cuối có attack surface nhỏ hơn vì ít package hệ điều hành và tool biên dịch hơn.
- **Tách rõ build và run**: pipeline có thể build lặp lại ổn định, còn container production chỉ làm nhiệm vụ chạy app.
- **Chạy non-root**: Dockerfile tạo user `app` và dùng `USER app`, giúp giảm rủi ro nếu ứng dụng bị khai thác.
- **Health check tích hợp**: Docker có thể tự kiểm tra `/health` để biết container có sẵn sàng nhận traffic hay không.

## 2. Describe the complete CI/CD pipeline flow from a developer pushing code to the application being deployed in production

Luồng CI/CD trong `.github/workflows/ci-cd.yml` hoạt động như sau:

1. **Developer push code hoặc tạo Pull Request vào `main`**.
2. **Lint stage** chạy `ruff check app tests` để phát hiện lỗi style, import, bug pattern và code smell cơ bản.
3. **Test stage** cài dependency, chạy `pytest`, tạo coverage report `coverage.xml` bằng `pytest-cov`.
4. **SonarQube scan stage** tải `coverage.xml`, phân tích source trong thư mục `app`, đọc test trong `tests`, gửi kết quả về SonarQube.
5. **Quality Gate stage** được cấu hình bằng `-Dsonar.qualitygate.wait=true`. Pipeline chờ SonarQube trả kết quả. Nếu fail, job SonarQube fail và các job sau không chạy.
6. **Build stage** chỉ chạy khi push lên `main`. Docker Buildx build image production từ Dockerfile multi-stage, tag theo commit SHA và push lên GitHub Container Registry.
7. **Deploy stage** chạy trên self-hosted runner ở môi trường production/staging. Runner pull image mới, chạy script Blue-Green deployment.
8. **Blue-Green deployment** deploy image mới vào môi trường không active, ví dụ production đang là blue thì deploy sang green.
9. **Health verification** kiểm tra container mới healthy qua Docker healthcheck và endpoint `/health`.
10. **Traffic switch** Nginx reload config để chuyển traffic sang color mới mà không stop container cũ trước, giúp giảm downtime.
11. **Rollback capability** nếu bản mới lỗi sau khi chuyển traffic, chạy `deploy/rollback.sh` để chuyển Nginx về color cũ còn đang healthy.

## 3. How does the SonarQube quality gate integrate with the pipeline, and what happens when the gate fails?


SonarQube được tích hợp ở job `sonarqube`. Job này chạy sau test để có coverage report. File `sonar-project.properties` khai báo:

- `sonar.sources=app`
- `sonar.tests=tests`
- `sonar.python.coverage.reportPaths=coverage.xml`
- `sonar.python.version=3.11`

Trong GitHub Actions, SonarQube scan chạy với tham số:

```bash
-Dsonar.qualitygate.wait=true
-Dsonar.qualitygate.timeout=300
```

Tham số này khiến CI runner chờ kết quả Quality Gate. Nếu Quality Gate **pass**, pipeline tiếp tục sang job build và deploy. Nếu Quality Gate **fail**, job `sonarqube` fail, job `build` không chạy vì có `needs: sonarqube`, và job `deploy` cũng không chạy vì có `needs: build`. Vì vậy, code không đạt chất lượng sẽ không được deploy.

Các rule thường dùng trong Quality Gate gồm coverage tối thiểu, duplicated lines, bugs, vulnerabilities, security hotspots, code smells và maintainability rating.

PYTHON ?= python3
IMAGE_NAME ?= fastapi-devops-pipeline
IMAGE_TAG ?= local
APP_PORT ?= 8080
SONAR_HOST_URL ?= http://host.docker.internal:9000

.PHONY: install lint test coverage docker-build docker-run sonar-up sonar-scan deploy rollback clean

install:
	$(PYTHON) -m pip install --upgrade pip
	$(PYTHON) -m pip install -r requirements-dev.txt

lint:
	ruff check app tests

test:
	pytest

coverage:
	pytest --cov=app --cov-report=term-missing --cov-report=xml

docker-build:
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

docker-run:
	docker run --rm -p 8000:8000 $(IMAGE_NAME):$(IMAGE_TAG)

sonar-up:
	docker compose -f docker-compose.sonar.yml up -d

sonar-scan: coverage
	docker run --rm -e SONAR_HOST_URL=$(SONAR_HOST_URL) -e SONAR_TOKEN=$$SONAR_TOKEN -v "$$(pwd):/usr/src" sonarsource/sonar-scanner-cli

deploy: docker-build
	IMAGE_NAME=$(IMAGE_NAME) IMAGE_TAG=$(IMAGE_TAG) APP_PORT=$(APP_PORT) ./deploy/blue-green-deploy.sh $(IMAGE_TAG)

rollback:
	APP_PORT=$(APP_PORT) ./deploy/rollback.sh

clean:
	rm -rf .pytest_cache .ruff_cache htmlcov coverage.xml .coverage

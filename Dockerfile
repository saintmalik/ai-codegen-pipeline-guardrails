# INTENTIONALLY BAD — agent-proposed Dockerfile (hadolint should fail).
FROM python:latest

RUN apt-get update && apt-get install -y curl wget

COPY . /app
WORKDIR /app

ENV SECRET_KEY=hardcoded-demo-secret

CMD python app/src/webhook.py

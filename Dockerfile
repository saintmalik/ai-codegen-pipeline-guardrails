# Fixed Dockerfile — same runtime story, hadolint-clean.
FROM python:3.12-slim

WORKDIR /app

COPY app/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY app/ /app/app/

USER 65534:65534

CMD ["python", "-m", "app.src.webhook"]

# build stage: install dependencies, nothing else lands in final image
FROM python:3.13-slim AS builder

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# final stage: minimal runtime, no build tools, no root
FROM python:3.13-slim

# create a dedicated non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app

# grab only the installed packages from the build stage, not the build tools
COPY --from=builder /root/.local /home/appuser/.local
COPY . .

# make sure appuser can actually read its own files
RUN chown -R appuser:appuser /app /home/appuser/.local

ENV PATH=/home/appuser/.local/bin:$PATH

USER appuser

EXPOSE 8001

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8001"]
# === Stage 1: Builder ===
FROM python:3.14-slim AS builder

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Install system dependencies required for building Python packages (like psycopg2)
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install python dependencies into a virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy just the requirements field to leverage Docker cache
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install -r requirements.txt

# === Stage 2: Runner ===
FROM python:3.14-slim AS runner

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

ARG user=django
ARG uid=1000

WORKDIR /app

# Install runtime system dependencies (for psycopg2)
RUN apt-get update && apt-get install -y \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*  

# Copy virtual environment from the builder stage
COPY --from=builder /opt/venv /opt/venv

# Copy local project into the container
COPY . .

RUN adduser devopsuser
RUN chown devopsuser:devopsuser /app
USER devopsuser

# Run the Django application
CMD ["gunicorn", "core.wsgi:application", "--bind", "0.0.0.0:8000"]

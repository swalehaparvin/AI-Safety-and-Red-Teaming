# AI Safety and Red Teaming - Docker Container
# =============================================
# Multi-stage build for efficient image size

# Stage 1: Base Python environment
FROM python:3.11-slim as base

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONFAULTHANDLER=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN groupadd --gid 1000 aisafety \
    && useradd --uid 1000 --gid 1000 -m aisafety

WORKDIR /app

# Stage 2: Dependencies
FROM base as dependencies

# Copy dependency files
COPY requirements.txt pyproject.toml ./

# Install Python dependencies
RUN pip install --upgrade pip setuptools wheel \
    && pip install -r requirements.txt

# Stage 3: Development image
FROM dependencies as development

# Install development dependencies
RUN pip install \
    pytest \
    pytest-cov \
    pytest-asyncio \
    black \
    isort \
    mypy \
    ruff \
    jupyter \
    ipython

# Copy source code
COPY --chown=aisafety:aisafety . .

# Switch to non-root user
USER aisafety

# Expose Jupyter port
EXPOSE 8888

# Default command for development
CMD ["jupyter", "notebook", "--ip=0.0.0.0", "--port=8888", "--no-browser"]

# Stage 4: Production image
FROM dependencies as production

# Copy only necessary files
COPY --chown=aisafety:aisafety ai_safety_redteaming/ ./ai_safety_redteaming/
COPY --chown=aisafety:aisafety tools/ ./tools/
COPY --chown=aisafety:aisafety datasets/ ./datasets/

# Switch to non-root user
USER aisafety

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import ai_safety_redteaming; print('OK')" || exit 1

# Default command
CMD ["python", "-m", "ai_safety_redteaming"]

# Stage 5: Gradio/Web Application
FROM dependencies as webapp

# Install web dependencies
RUN pip install gradio>=4.0.0 fastapi uvicorn

# Copy application code
COPY --chown=aisafety:aisafety 10-evaluation/falconz_redteamers/ ./falconz/

# Switch to non-root user
USER aisafety

# Expose Gradio port
EXPOSE 7860

# Run Gradio application
CMD ["python", "falconz/app.py"]

# Stage 6: Testing image
FROM development as testing

# Run tests by default
CMD ["pytest", "-v", "--cov=ai_safety_redteaming", "--cov-report=term-missing"]

# =============================================================================
# Build Commands:
# -----------------------------------------------------------------------------
# Development:  docker build --target development -t ai-safety:dev .
# Production:   docker build --target production -t ai-safety:prod .
# Web App:      docker build --target webapp -t ai-safety:web .
# Testing:      docker build --target testing -t ai-safety:test .
#
# Run Commands:
# -----------------------------------------------------------------------------
# Dev Jupyter:  docker run -p 8888:8888 -v $(pwd):/app ai-safety:dev
# Web App:      docker run -p 7860:7860 --env-file .env ai-safety:web
# Run Tests:    docker run ai-safety:test
# =============================================================================

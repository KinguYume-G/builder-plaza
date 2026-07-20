FROM python:3.12-slim

WORKDIR /app

RUN adduser --disabled-password --gecos "" appuser

# CPU-only torch first: the default wheel drags CUDA (~2GB) the Fargate task
# can't use. Then the rest of the requirements resolve against it.
COPY requirements.txt .
RUN pip install --no-cache-dir --index-url https://download.pytorch.org/whl/cpu torch \
    && pip install --no-cache-dir -r requirements.txt

COPY app ./app

USER appuser

# Pre-bake the MiniLM encoder (ADR-0001) into the image so the first
# /matches call doesn't spend ~30s downloading the model at runtime.
ENV HF_HOME=/home/appuser/.cache/huggingface
RUN python -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('all-MiniLM-L6-v2')"

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

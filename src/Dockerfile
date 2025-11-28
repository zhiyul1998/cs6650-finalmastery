FROM python:3.11-slim

WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

EXPOSE 8080
# Use 0.0.0.0 for container networking; single worker is fine for this assignment
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
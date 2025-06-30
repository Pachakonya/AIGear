FROM python:3.10-slim

WORKDIR /app

COPY . .

RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 8000

CMD ["uvicorn", "src.main:app", "--host", "127.0.0.1", "--port", "8000", "--workers", "4"]
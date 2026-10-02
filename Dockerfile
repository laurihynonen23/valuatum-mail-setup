FROM python:3.13-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY mail_server.py bridge.py ./
RUN useradd --create-home appuser
USER appuser
CMD ["python", "bridge.py"]

FROM python:3.12-slim
WORKDIR /app
RUN pip install --no-cache-dir aiohttp==3.10.11
COPY sanitize.py .
EXPOSE 8010
ENTRYPOINT ["python", "sanitize.py"]

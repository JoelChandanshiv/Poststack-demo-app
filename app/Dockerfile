FROM python:3.12-alpine

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

ENV APP_PORT=8080
EXPOSE 8080

# Runs as a non-root user - alpine's python image already has one
# available, no need to create a custom one for something this small.
USER nobody

CMD ["python", "app.py"]

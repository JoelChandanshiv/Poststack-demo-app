#!/bin/bash
set -e

for i in $(seq 1 10); do
  if curl -sf http://localhost:8080/health > /dev/null; then
    echo "Health check passed on attempt $i"
    exit 0
  fi
  echo "Waiting for app to become healthy (attempt $i/10)..."
  sleep 3
done

echo "Health check failed after 10 attempts - failing deployment"
exit 1

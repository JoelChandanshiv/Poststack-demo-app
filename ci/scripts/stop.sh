#!/bin/bash
set -e

if sudo docker ps -a --format '{{.Names}}' | grep -q '^poststack-app$'; then
  echo "Stopping existing poststack-app container"
  sudo docker stop poststack-app || true
  sudo docker rm poststack-app || true
else
  echo "No existing poststack-app container found - nothing to stop"
fi

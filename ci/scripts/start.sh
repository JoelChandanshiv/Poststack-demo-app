#!/bin/bash
set -e

source /opt/poststack-app/deploy_vars.env
if [ -z "${IMAGE_URI:-}" ]; then
  echo "IMAGE_URI not found in deploy_vars.env - cannot continue"
  exit 1
fi

REGION="ap-south-2"
REPO_HOST="${IMAGE_URI%%/*}"

aws ecr get-login-password --region "$REGION" | sudo docker login --username AWS --password-stdin "$REPO_HOST"
sudo docker pull "$IMAGE_URI"

sudo docker run -d \
  --name poststack-app \
  --restart unless-stopped \
  -p 8080:8080 \
  -e ENVIRONMENT=dev \
  -e BEDROCK_REGION=ap-south-1 \
  -e BEDROCK_MODEL_ID=global.amazon.nova-2-lite-v1:0 \
  "$IMAGE_URI"

echo "Started container from $IMAGE_URI"

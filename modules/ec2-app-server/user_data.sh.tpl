#!/bin/bash
set -euxo pipefail

# Docker
dnf install -y docker
systemctl enable --now docker
usermod -aG docker ec2-user

# CodeDeploy agent — required for the CodeDeploy deployment group (Phase 5)
# to be able to deploy the application container to this instance.
# NOTE: verify the aws-codedeploy-${aws_region} S3 bucket exists in
# ap-south-2 before relying on this — CodeDeploy is a regional service and
# newer regions occasionally lag on having this bucket populated. If it's
# missing, the CodeDeploy agent install step needs an alternate source.
dnf install -y ruby wget
cd /home/ec2-user
wget https://aws-codedeploy-${aws_region}.s3.${aws_region}.amazonaws.com/latest/install
chmod +x ./install
./install auto
systemctl enable --now codedeploy-agent

# CloudWatch Agent — ships logs/metrics, IAM permissions already attached
# via the instance profile (CloudWatchAgentServerPolicy).
dnf install -y amazon-cloudwatch-agent

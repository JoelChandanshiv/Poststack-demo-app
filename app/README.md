# Dummy App — Manual Verification

This app exists purely to prove your infrastructure works end to end
(ALB → target group → app server → Docker container) before the real
application deploy pipeline exists. Once `platform/terraform-pipeline`
and the (still-unbuilt) app deploy pipeline are live, this becomes
unnecessary — but for right now, here's how to deploy it manually.

## Prerequisite: platform/ecr must be applied

If you haven't already:
```
cd platform/ecr
cp backend.tf.example backend.tf   # fill in state bucket + KMS key
terraform init && terraform apply
terraform output repository_url
```

## 1. Build and push the image (from your dev server, needs Docker installed)

```bash
cd app

REPO_URL=$(cd ../platform/ecr && terraform output -raw repository_url)
aws ecr get-login-password --region ap-south-2 | docker login --username AWS --password-stdin "${REPO_URL%/*}"

docker build -t poststack-app:manual-test .
docker tag poststack-app:manual-test "${REPO_URL}:manual-test"
docker push "${REPO_URL}:manual-test"
```

## 2. Run it on the dev app server

Get on the app server via SSM (no SSH key needed):
```bash
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=poststack-dev-app-server" --query 'Reservations[].Instances[].InstanceId' --region ap-south-2 --output text)
aws ssm start-session --target "$INSTANCE_ID" --region ap-south-2
```

Then, on the app server itself:
```bash
REPO_URL=<paste the same repository_url from step 1>
aws ecr get-login-password --region ap-south-2 | sudo docker login --username AWS --password-stdin "${REPO_URL%/*}"
sudo docker pull "${REPO_URL}:manual-test"
sudo docker run -d --name poststack-app -p 8080:8080 -e ENVIRONMENT=dev "${REPO_URL}:manual-test"
sudo docker ps   # confirm it's running
curl localhost:8080/health   # confirm it responds locally first
```

## 3. Confirm the ALB sees it as healthy

From your dev server (or anywhere with AWS CLI access):
```bash
TG_ARN=$(aws elbv2 describe-target-groups --names poststack-dev-app-tg --region ap-south-2 --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 describe-target-health --target-group-arn "$TG_ARN" --region ap-south-2
```
Look for `"State": "healthy"`. It can take up to ~30-45 seconds after the
container starts for the first health check to pass (health_check
interval is 15s, healthy_threshold is 2 consecutive passes).

## 4. Hit it through the actual ALB

The ALB's DNS name is assigned by AWS and changes if the ALB is ever
recreated (e.g. after a `terraform destroy`) - always fetch the current
value rather than reusing one from an earlier session:
```bash
ALB_DNS=$(cd ../environments/dev && terraform output -raw alb_dns_name)
curl "http://${ALB_DNS}/"
```
You should see the dummy app's HTML page, including the container's
hostname — confirming the full path from the internet-facing ALB all the
way down to a container on the private app server actually works.

## Cleanup (optional, once verified)

```bash
# back in the SSM session on the app server:
sudo docker stop poststack-app && sudo docker rm poststack-app
```

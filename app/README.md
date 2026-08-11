# Dummy App — Manual Verification

This app exists purely to prove your infrastructure works end to end
(ALB → target group → app server → Docker container) before the real
application deploy pipeline exists. Once `platform/terraform-pipeline`
and the (still-unbuilt) app deploy pipeline are live, this becomes
unnecessary — but for right now, here's how to deploy it manually.

## Prerequisite: enable Bedrock model access (one-time, Console)

The app calls Amazon Bedrock — **Nova 2 Lite** via a cross-region
inference profile (`global.amazon.nova-2-lite-v1:0`) — for a small chat
demo. This requires "Model access" to be enabled for the underlying model
in this account — a one-time step that, as far as I'm aware, still has to
be done in the Console (Terraform/IAM alone doesn't grant it — the IAM
policy in `modules/iam` is necessary but not sufficient).

**Note on data residency:** this model is only reachable via a
cross-region inference profile whose destination is described by AWS as
"Commercial AWS Regions" (broad, not limited to one geography). Confirmed
via `aws bedrock list-inference-profiles --region ap-south-1`, which
returned exactly two underlying model ARNs: one with no region segment at
all, and one scoped to `ap-south-1`. Requests are not guaranteed to stay
in `ap-south-2`, or even in India — this was a deliberate choice for this
demo (two earlier models were tried first: Titan Text Express, since
retired by AWS entirely, then a Claude Haiku profile that turned out not
to be registered in this account's `ap-south-2`; Nova 2 Lite's `global`
profile is the one actually confirmed working via CLI).

1. AWS Console → region switched to **Asia Pacific (Mumbai) ap-south-1**
   (the profile itself is registered there, confirmed via CLI) → Bedrock
   → **Model access**
2. Find **Nova 2 Lite** (publisher: Amazon) → request/enable access
3. Confirm it shows "Access granted" before testing the chat endpoint

If you skip this, `/chat` will return a 502 with the raw Bedrock error
(likely `AccessDeniedException` mentioning model access) — the app
deliberately surfaces the real error instead of a generic failure, so
that's your signal this step is still pending.

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
sudo docker run -d --name poststack-app -p 8080:8080 -e ENVIRONMENT=dev -e BEDROCK_REGION=ap-south-1 -e BEDROCK_MODEL_ID=global.amazon.nova-2-lite-v1:0 "${REPO_URL}:manual-test"
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

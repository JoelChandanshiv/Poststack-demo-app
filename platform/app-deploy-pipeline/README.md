# App Deploy Pipeline

Cross-region CodePipeline: Source in `ap-south-1` (GitHub CodeConnection),
Build + Deploy in `ap-south-2` (CodeDeploy must be in the same region as
the target EC2 instance — a real AWS constraint, see the comment at the
top of `main.tf`).

## Before you apply

1. **Make the deploy scripts executable in git** — CodeDeploy runs them
   directly, and a script without the executable bit will fail silently
   or with a permission error:
   ```bash
   chmod +x ci/scripts/*.sh
   git add ci/scripts/*.sh
   git update-index --chmod=+x ci/scripts/*.sh
   git commit -m "Make deploy scripts executable"
   git push
   ```

2. **Stop your manually-started container first, if it's still running.**
   CodeDeploy's `ApplicationStop` hook does NOT run on the very first
   deployment to an instance (no previous revision to reference yet) — so
   it won't clean up a container that was started outside CodeDeploy.
   Every deployment after the first is handled automatically.
   ```bash
   # via SSM, or SSH+agent-forwarding through the bastion:
   sudo docker stop poststack-app && sudo docker rm poststack-app
   ```
   (Skip this if you already cleaned it up.)

## Apply

```bash
cd platform/app-deploy-pipeline
cp backend.tf.example backend.tf
# fill in <STATE_BUCKET_NAME> and <KMS_KEY_ARN> from bootstrap's output

cat > terraform.tfvars << 'EOF'
github_connection_arn     = "<same connection_arn as platform/terraform-pipeline>"
github_full_repository_id = "<owner>/<repo>"
ecr_repository_url        = "<from platform/ecr output>"
ecr_repository_arn        = "<from platform/ecr output>"
branch_name                = "develop"   # match whatever you actually used
EOF

terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

## What happens on the next push to your branch

Source → Build (docker build + push to ECR) → Deploy (CodeDeploy rolls it
onto the app server, running `stop.sh` → copies files → `start.sh` →
`validate.sh`). Watch it in the Console under CodePipeline (note: the
pipeline itself is visible in `ap-south-2`, since that's its primary
region, even though the Source action executes in `ap-south-1`).

## Verify

```bash
ALB_DNS=$(cd ../../environments/dev && terraform output -raw alb_dns_name)
curl "http://${ALB_DNS}/"
```
Should show the same dummy app page as before, but now deployed by the
pipeline instead of manually.

# PostStack Migration — Terraform AWS Infrastructure

Region: `ap-south-2` (Hyderabad) for all actual infrastructure — VPC, EC2,
RDS, ALB, everything in `environments/dev` and `environments/prod`. Two
fully isolated environments (`dev`, `prod`), each with its own state file,
own VPC, own app server, own database. No AMS/DMS/Replication Server/
Athena (excluded per project scope).

**One documented exception:** the CI/CD control plane — `aws_codestarconnections_connection`
(GitHub), the CodePipeline pipelines, their CodeBuild projects, and the
pipeline artifact bucket in `platform/github-connection`,
`platform/terraform-pipeline`, and `platform/drift-detection` — runs in
`ap-south-1` (Mumbai), not `ap-south-2`. This is because AWS CodeConnections
(the service `aws_codestarconnections_connection` depends on) does not
support `ap-south-2` as of this writing — confirmed against AWS's region
docs after hitting a live `dial tcp: ... no such host` error trying to
create it there. This does not affect where infrastructure is deployed:
the `terraform apply` that runs *inside* CodeBuild still targets
`ap-south-2`, because each `environments/<env>` config sets its own AWS
provider region independently of whatever region CodeBuild itself executes
in. If AWS adds CodeConnections support for `ap-south-2` later, the fix is
a one-line variable change (`aws_region` in the three `platform/*` configs
listed above), not a redesign.

## Full apply order (start to finish)

Run each of these from your dev server. Steps 1–3 are one-time/shared.
Steps 4–5 you'll normally only ever do through the CI/CD pipeline once
it exists — the first time, you do them manually to get the pipeline
itself stood up.

### 1. Bootstrap (one-time)
```
cd bootstrap
terraform init && terraform validate && tflint --init && tflint
terraform plan -out=bootstrap.tfplan
terraform apply bootstrap.tfplan
terraform output   # note state_bucket_name and state_bucket_kms_key_arn
```
See `bootstrap/README.md` for full detail, including optionally migrating
bootstrap's own state into the bucket it just created.

### 2. Platform: ECR (one-time, shared by dev+prod)
```
cd platform/ecr
cp backend.tf.example backend.tf   # fill in bucket name + KMS key ARN
terraform init && terraform validate && terraform plan -out=tfplan
terraform apply tfplan
terraform output   # note repository_url and repository_arn
```

### 3. Platform: GitHub connection (one-time, in ap-south-1 — see note at top of this file)
```
cd platform/github-connection
cp backend.tf.example backend.tf
terraform init && terraform apply
terraform output connection_arn
```
This creates the connection resource in `ap-south-1` (Mumbai), not
`ap-south-2` — see the top of this README for why. The state file itself
still lives in the `ap-south-2` state bucket from bootstrap; only the
`aws_codestarconnections_connection` resource is created in a different
region.

Then: AWS Console → Developer Tools → Settings → Connections → **switch
the region selector to Asia Pacific (Mumbai) ap-south-1** → find the
`poststack-github` connection (status: PENDING) → **Update pending
connection** → authorize with GitHub. This is the one legitimate manual
Console step in the entire project — see the comment in
`platform/github-connection/main.tf` for why it can't be scripted.

### 4. Environments: dev, then prod (manual the first time)
```
cd environments/dev
cp backend.tf.example backend.tf         # fill in bucket name + KMS key ARN
cp terraform.tfvars.example terraform.tfvars   # fill in admin_cidr_blocks, bastion_ssh_key_name, ecr_repository_arn (from step 2)
terraform init && terraform validate && tflint --init && tflint
terraform plan -out=tfplan
terraform apply tfplan
```
Repeat for `environments/prod` (separate `terraform.tfvars`, separate SSH
key pair, expect Multi-AZ RDS + per-AZ NAT to take noticeably longer).

**Do not apply prod until dev is fully verified** (ALB reachable, app
deployable, DB reachable only from the app/bastion).

### 5. Platform: Terraform CI/CD pipeline (one-time, control plane in ap-south-1)
```
cd platform/terraform-pipeline
cp backend.tf.example backend.tf
# set: github_connection_arn (step 3), github_full_repository_id,
#      state_bucket_name + state_bucket_kms_key_arn (step 1),
#      notification_email
terraform init && terraform apply
```
The CodePipeline/CodeBuild resources this creates run in `ap-south-1`
(default `aws_region` in this config) — the `terraform apply` they run
still targets `ap-south-2`, unaffected. From here on, changes to
`environments/dev/**` on the `develop` branch and `environments/prod/**`
on the `main` branch go through the pipeline — fmt → validate → tflint →
checkov (informational) → plan → (prod: manual approval) → apply. Step 4's
manual runs were only needed to bootstrap the pipeline itself.

### 6. Platform: Drift detection (one-time, control plane in ap-south-1)
```
cd platform/drift-detection
cp backend.tf.example backend.tf
# set: github_connection_arn, github_full_repository_id,
#      state_bucket_name + state_bucket_kms_key_arn, notification_email
terraform init && terraform apply
```
Runs a `terraform plan -detailed-exitcode` against dev and prod daily
(schedules in `variables.tf`) — the plan itself checks `ap-south-2`
resources, the CodeBuild job running it lives in `ap-south-1`. No drift →
silence. Drift found → an email via SNS with the plan summary, and it
stops there — nothing auto-applies. A real plan error (not drift) also
alerts, tagged distinctly so it isn't confused with drift.

## What's built vs. what's still open

**Built:** state backend, networking, security groups, IAM, secrets,
RDS, bastion, ALB, app server, CloudWatch alarms, AWS Backup, S3 storage,
ECR, GitHub connection, the Terraform CI/CD pipeline (lint/validate/plan/
approve/apply), and drift detection — for both dev and prod.

**Not built yet:** the *application* deploy pipeline shown in your
original diagram (CodePipeline → CodeBuild → ECR → CodeDeploy → EC2, for
deploying your app's Docker image, as opposed to deploying infrastructure
changes). `ci/buildspec-app.yml` and `ci/appspec.yml` need to exist and a
`modules/app-deploy-pipeline` needs writing once you can tell me what the
application actually is (build steps, container port, health check
behavior) — say the word when you're ready for that piece.

## Tagging & naming convention

Every resource: `ManagedBy=terraform`, `Project=poststack`,
`Environment=dev|prod` (plus `Scope=bootstrap|platform` for the
non-environment-specific pieces). Names follow `poststack-<env>-<resource>`,
e.g. `poststack-dev-alb`, `poststack-prod-postgres`.

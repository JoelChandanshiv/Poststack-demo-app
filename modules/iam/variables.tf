variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  description = "Needed to construct region-scoped ARNs for the bastion's SSM caller policy."
  type        = string
}

variable "bedrock_region" {
  description = "Region the Bedrock inference profile itself lives in - separate from var.aws_region (ap-south-2, used for everything else in this project) since this profile was confirmed via `aws bedrock list-inference-profiles` to be registered in ap-south-1, not ap-south-2. The app server (in ap-south-2) calls out to this region over a normal regional API call - no networking constraint, same pattern already proven by the CI/CD pipeline's cross-region actions."
  type        = string
  default     = "ap-south-1"
}

variable "bedrock_inference_profile_ids" {
  description = "Bedrock cross-region inference profile IDs the app server is allowed to invoke. Must also have 'Model access' enabled for the underlying model in the Bedrock Console (a separate, one-time, per-account requirement that IAM alone doesn't grant). Confirmed via `aws bedrock list-inference-profiles --region ap-south-1` that this specific profile is real and active."
  type        = list(string)
  default     = ["global.amazon.nova-2-lite-v1:0"]
}

variable "bedrock_underlying_model_arns" {
  description = "Exact underlying model ARNs the inference profile(s) above can route to - IAM permission is needed on these, not just the profile itself. Taken directly from `aws bedrock list-inference-profiles --region ap-south-1` output's `models[].modelArn` field for this profile - not guessed. One entry deliberately has no region segment (AWS's own wildcard-style ARN for this global profile)."
  type        = list(string)
  default = [
    "arn:aws:bedrock:::foundation-model/amazon.nova-2-lite-v1:0",
    "arn:aws:bedrock:ap-south-1::foundation-model/amazon.nova-2-lite-v1:0",
  ]
}

variable "ecr_repository_arns" {
  description = "ECR repository ARNs the app server is allowed to pull images from."
  type        = list(string)
}

variable "secret_arns" {
  description = "Secrets Manager secret ARNs the app server is allowed to read."
  type        = list(string)
}

variable "kms_key_arns" {
  description = "KMS key ARNs needed to decrypt the above secrets, if they use a customer-managed key."
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}

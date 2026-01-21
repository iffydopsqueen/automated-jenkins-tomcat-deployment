variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "The project name"
  type        = string
}

variable "github_actions_role_name" {
  description = "IAM role name for GitHub Actions OIDC"
  type        = string
  default     = "GitHubAction-OIDCAssumeRole"
}

variable "github_actions_subjects" {
  description = "Allowed GitHub Actions OIDC subject claims"
  type        = list(string)
  default     = ["repo:iffydopsqueen/*"]
}

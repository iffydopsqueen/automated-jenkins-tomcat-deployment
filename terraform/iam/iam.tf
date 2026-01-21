# This fetches the TLS certificate chain for the GitHub Actions OIDC provider
data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

# Create the IAM OIDC provider for GitHub Actions
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_actions.certificates[0].sha1_fingerprint]

  tags = {
    Project = var.project
  }
}

# IAM Role Policy for GitHub Actions to assume via OIDC
data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.github_actions_subjects
    }
  }
}

# Create the IAM Role for GitHub Actions OIDC
resource "aws_iam_role" "github_actions" {
  name               = var.github_actions_role_name
  description        = "GitHub Actions OIDC role for Terraform pipeline"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = {
    Project = var.project
  }
}

# Attach necessary policies to the GitHub Actions IAM Role (permissions to manage EC2 and VPC)
resource "aws_iam_role_policy_attachment" "github_actions" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
    "arn:aws:iam::aws:policy/AmazonVPCFullAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
  ])

  role       = aws_iam_role.github_actions.name
  policy_arn = each.value
}

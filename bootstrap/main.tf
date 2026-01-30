locals {
  state_bucket_name = var.bucket_name != "" ? var.bucket_name : "${var.app_name}-tf-state-file"
  common_tags       = merge(var.tags, { app = var.app_name })
  github_repo_full  = "${var.github_org}/${var.github_repo}"
  github_subjects = [
    "repo:${local.github_repo_full}:ref:refs/heads/*",
    "repo:${local.github_repo_full}:pull_request",
  ]
}

data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_s3_bucket" "state" {
  #checkov:skip=CKV_AWS_18: "Access logging not required for Terraform state bucket in this POC"
  #checkov:skip=CKV2_AWS_62: "Event notifications not required for Terraform state bucket in this POC"
  #checkov:skip=CKV2_AWS_61: "Lifecycle policy not required for Terraform state bucket in this POC"
  #checkov:skip=CKV_AWS_144: "Cross-region replication not required for Terraform state bucket in this POC"
  #checkov:skip=CKV_AWS_145: "KMS encryption not required for Terraform state bucket in this POC"
  bucket        = local.state_bucket_name
  force_destroy = var.force_destroy
  tags          = local.common_tags
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
  client_id_list = [
    "sts.amazonaws.com",
  ]
  thumbprint_list = [
    data.tls_certificate.github_actions.certificates[0].sha1_fingerprint,
  ]
  tags = local.common_tags
}

data "aws_iam_policy_document" "github_oidc_assume_role" {
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
      values   = local.github_subjects
    }
  }
}

resource "aws_iam_role" "github_actions_plan" {
  name_prefix        = "${var.app_name}-github-oidc-"
  assume_role_policy = data.aws_iam_policy_document.github_oidc_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "github_actions_readonly" {
  role       = aws_iam_role.github_actions_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "tf_state_access" {
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetObjectVersion",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]
    resources = ["${aws_s3_bucket.state.arn}/*"]
  }
}

resource "aws_iam_policy" "tf_state_access" {
  name_prefix = "${var.app_name}-tfstate-"
  policy      = data.aws_iam_policy_document.tf_state_access.json
  tags        = local.common_tags
}

resource "aws_iam_role_policy_attachment" "github_actions_tfstate" {
  role       = aws_iam_role.github_actions_plan.name
  policy_arn = aws_iam_policy.tf_state_access.arn
}


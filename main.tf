data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_s3_bucket" "canary" {
  bucket = var.bucket_name
}

locals {
  ssm_prefix            = module.ssm_prefix.full_prefix
  should_create_kms_key = ! (length(var.kms_key_arn) > 0)
  kms_key_arn           = local.should_create_kms_key ? module.kms_key[0].key_arn : var.kms_key_arn
}

module "label" {
  source  = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.19.2"
  context = module.this.context
}

module "kms_key" {
  source = "git::https://github.com/cloudposse/terraform-aws-kms-key.git?ref=tags/0.7.0"

  count = local.should_create_kms_key ? 1 : 0

  context                 = module.this.context
  description             = "KMS key for canary ${module.label.id}"
  deletion_window_in_days = 10
  enable_key_rotation     = "true"
  alias                   = "alias/${module.label.id}_kms_key"
}


#########################################################################################
# IAM resources

data "aws_iam_policy_document" "assume" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole"
    ]
  }
}

data "aws_iam_policy_document" "canary" {

  statement {
    sid = "CanaryStoreResultsInS3"
    actions = [
      "s3:PutObject",
      "s3:GetBucketLocation"
    ]
    resources = [
      "arn:aws:s3:::${data.aws_s3_bucket.canary.id}/canary/${var.canary_name}/*"
    ]
  }
  statement {
    sid = "CanaryListBucketsXray"
    actions = [
      "s3:ListAllMyBuckets",
      "xray:PutTraceSegments"
    ]
    resources = ["*"]
  }
  statement {
    sid = "CanaryPutMetricsData"
    actions = [
      "cloudwatch:PutMetricData"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["CloudWatchSynthetics"]
    }
  }

  statement {
    sid = "CanaryLogLambdaOutput"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:CreateLogGroup"
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/cwsyn-${var.canary_name}-*"
    ]
  }
}

data "aws_iam_policy_document" "secrets" {
  statement {
    effect = "Allow"
    sid    = "SecretsManagerActions"

    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue"
    ]
    resources = var.secretsmanager_secret_arns
  }
}

resource "aws_iam_role" "canary" {
  name               = module.label.id
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = module.label.tags
}

resource "aws_iam_policy" "canary" {
  name        = module.this.id
  description = "Canary policy"
  policy      = data.aws_iam_policy_document.canary.json
}

resource "aws_iam_role_policy_attachment" "canary" {
  role       = aws_iam_role.canary.name
  policy_arn = aws_iam_policy.canary.arn
}

resource "aws_iam_policy" "secrets" {
  count       = length(var.secretsmanager_secret_arns) > 0 ? 1 : 0
  name        = module.this.id
  description = "Allow secret read access to some secrets"
  policy      = data.aws_iam_policy_document.secrets.json
}

resource "aws_iam_role_policy_attachment" "secrets" {
  count      = length(var.secretsmanager_secret_arns) > 0 ? 1 : 0
  role       = aws_iam_role.canary.name
  policy_arn = aws_iam_policy.secrets[0].arn
}

module "ssm_prefix" {
  source = "git::https://gitlab.com/guardianproject-ops/terraform-aws-ssm-param-store-iam?ref=tags/3.2.0"

  path_prefix       = "${module.label.id}"
  prefix_with_label = false
  region            = data.aws_region.current.name
  kms_key_arn       = local.kms_key_arn
  context           = module.label.context
  attributes        = module.label.attributes
}

resource "aws_iam_role_policy_attachment" "ssm_prefix" {
  role       = aws_iam_role.canary.name
  policy_arn = module.ssm_prefix.policy_arn
}


module "this" {
  source = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.19.2"

  namespace   = "gp-ops"
  environment = "dev"
  name        = "canary-test"
}

#############################################################################
# S3 Bucket

# This bucket might already exist if you have used canaries in the account before
resource "aws_s3_bucket" "bucket" {
  bucket = var.bucket_name
  acl    = "private"

  force_destroy = var.force_destroy

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = module.this.tags
}

#############################################################################
# Canary

module "canary" {
  source = "../"

  canary_name = var.canary_name
  bucket_name = aws_s3_bucket.bucket.id
  context     = module.this.context
}

locals {
  params = {
    a_canary_input = "foobar"
  }
}

resource "aws_ssm_parameter" "canary" {
  for_each = local.params
  name     = "${module.canary.ssm_prefix}/${each.key}"
  type     = "SecureString"
  value    = each.value
  tags     = module.this.tags
}


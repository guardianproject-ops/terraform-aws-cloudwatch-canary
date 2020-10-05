output "canary_name" {
  value = var.canary_name
}
output "role_name" {
  value = aws_iam_role.canary.name
}
output "ssm_prefix" {
  value = module.ssm_prefix.full_prefix
}
output "bucket_name" {
  value = data.aws_s3_bucket.canary.id
}

output "arn" {
 description = "The ARN of the created s3 bucket."
 value       = module.this.s3_bucket_arn
}

output "bucket_arn" {
 description = "DEPRECATED use arn instead."
 value       = module.this.s3_bucket_arn
}

output "bucket_name" {
 description = "The name of the created s3 bucket."
 value       = module.this.s3_bucket_id
}

output "mrap_alias" {
 description = "Alias URL of the Multi-Region Access Point"
 value       = var.mrap_name != null && length(var.mrap_regions) > 0 ? aws_s3control_multi_region_access_point.this[0].alias : null
}

output "mrap_arn" {
 description = "ARN of the Multi-Region Access Point"
 value       = var.mrap_name != null && length(var.mrap_regions) > 0 ? aws_s3control_multi_region_access_point.this[0].arn : null
}

output "mrap_iam_policy_arn" {
 description = "ARN of the IAM policy for S3 Multi-Region Access Point, if enabled."
 value       = var.mrap_iam != null ? aws_iam_policy.mrap[0].arn : null
}

output "mrap_iam_role_arn" {
 description = "ARN of the IAM role for S3 Multi-Region Access Point, if enabled."
 value       = var.mrap_iam != null ? aws_iam_role.mrap[0].arn : null
}

output "mrap_iam_role_name" {
 description = "Name of the IAM role for S3 Multi-Region Access Point, if enabled."
 value       = var.mrap_iam != null ? aws_iam_role.mrap[0].name : null
}

output "replication_configuration_id" {
 description = "The ID of the replication configuration, if enabled."
 value       = var.replication_configuration != null ? aws_s3_bucket_replication_configuration.this[0].id : null
}

output "replication_iam_policy_arn" {
 description = "ARN of the IAM policy for S3 replication, if enabled."
 value       = var.replication_iam != null ? aws_iam_policy.replication[0].arn : null
}

output "replication_iam_role_arn" {
 description = "ARN of the IAM role for S3 replication, if enabled."
 value       = var.replication_iam != null ? aws_iam_role.replication[0].arn : null
}

output "replication_iam_role_name" {
 description = "Name of the IAM role for S3 replication, if enabled."
 value       = var.replication_iam != null ? aws_iam_role.replication[0].name : null
}

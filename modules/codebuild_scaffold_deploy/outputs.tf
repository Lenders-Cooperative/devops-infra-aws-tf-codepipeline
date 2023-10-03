output "aws_sns_topic_arn" {
  value = module.codebuild-notification.aws_sns_topic_arn
}

output "codestar_connection_github_arn" {
  value = aws_codestarconnections_connection.codestar-connection-github.arn
}

output "artifact_store_id" {
  value = aws_s3_bucket.artifact-store.id
}

output "artifact_store_arn" {
  value = aws_s3_bucket.artifact-store.arn
}

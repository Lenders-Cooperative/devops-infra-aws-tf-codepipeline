resource "aws_codestarconnections_connection" "codestar-connection-github" {
  name          = "github-${var.source_credential_organization}"
  provider_type = "GitHub"
}

resource "aws_codebuild_source_credential" "authorization" {
  count       = var.codebuild_enabled && var.private_repository ? 1 : 0
  auth_type   = var.source_credential_auth_type
  server_type = var.source_credential_server_type
  token       = var.source_credential_token
  user_name   = var.source_credential_user_name
}
resource "aws_s3_bucket" "artifact-store" {
  bucket        = "codepipeline-${var.aws_region}-${var.aws-acct-id}"
  force_destroy = true
}

resource "aws_s3_bucket_acl" "artifact-store-acl" {
  bucket = aws_s3_bucket.artifact-store.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "artifact-store-versioning" {
  bucket = aws_s3_bucket.artifact-store.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifact-store-sse" {
  bucket = aws_s3_bucket.artifact-store.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


#Adding the alert lambda
module "codebuild-notification" {
  source                      = "./codebuild_alert"
  environment                 = var.environment
  aws_region                  = var.aws_region
  aws-acct-id                 = var.aws-acct-id
  source_credential_user_name = var.source_credential_user_name
  source_credential_token     = var.source_credential_token
  slack_token                 = var.slack_token
  slack_email_domain_filter   = var.slack_email_domain_filter
}

##################################################################################
# NOTE: Manually add the CloudWatch Logs trigger to the 
#       DatadogIntegration-ForwarderStack-1KIFSH-Forwarder-QFLXSe3mhj0t lambda
#       so we get the CloudWatch logs pushed to DataDog
##################################################################################

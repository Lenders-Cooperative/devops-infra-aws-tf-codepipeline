variable "name" {
  type        = string
  description = "CodePipeline name"
}

variable "source_location_trimmed" {
  type        = string
  description = "The location of the git repository without the https://github.com or .git"
}

variable "source_version" {
  type        = string
  description = "A version (i.e. branch name) of the build input to be built for this project. If not specified, the latest version is used."
}

variable "codestar_connection_arn" {
  type        = string
  description = "The ARN of the CodeStar connection to GitHUb for use in CodePipeline"
}

variable "artifact_store_id" {
  type        = string
  description = "The name of the S3 bucket to store source artifacts for the pipeline"
}

variable "aws_region" {
  type        = string
  description = "AWS Region, e.g. us-east-1. Used to specify IAM Role Name"
}

variable "slack_notification_channel" {
  type        = string
  default     = ""
  description = "Slack Channel Name to tag CodeBuild or CodePipeline and send build event notification messages"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags (e.g. `map('BusinessUnit', 'XYZ')`"
}

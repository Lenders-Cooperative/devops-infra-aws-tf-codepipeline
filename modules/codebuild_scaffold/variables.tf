variable "environment" {}
variable "aws_region" {}
variable "aws-acct-id" {}

variable "codebuild_enabled" {
  type        = bool
  default     = true
  description = "A boolean to enable/disable resource creation"
}

variable "private_repository" {
  type        = bool
  default     = false
  description = "Set to true to login into private repository with credentials supplied in source_credential variable."
}

variable "source_credential_auth_type" {
  type        = string
  default     = "PERSONAL_ACCESS_TOKEN"
  description = "The type of authentication used to connect to a GitHub, GitHub Enterprise, or Bitbucket repository."
}

variable "source_credential_server_type" {
  type        = string
  default     = "GITHUB"
  description = "The source provider used for this project."
}
variable "env" {}

variable "source_credential_token" {
  type        = string
  default     = ""
  description = "For GitHub or GitHub Enterprise, this is the personal access token. For Bitbucket, this is the app password."
}

variable "source_credential_user_name" {
  type        = string
  default     = ""
  description = "The Bitbucket username when the authType is BASIC_AUTH. This parameter is not valid for other types of source providers or connections."
}

variable "source_credential_organization" {
  type        = string
  description = "The GitHub Organization name for the source repositories and service account token."
}

variable "slack_token" {
  type        = string
  default     = ""
  description = "The OAuth Token for the Slack App Bot to use to post messages"
}

variable "slack_email_domain_filter" {
  type        = string
  default     = ""
  description = "The email domain of GitHub users to include as an at mention in Slack Messages"
}

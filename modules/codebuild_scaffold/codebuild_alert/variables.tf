variable "environment" {}
variable "aws_region" {}
variable "aws-acct-id" {}

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

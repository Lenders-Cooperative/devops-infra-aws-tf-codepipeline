variable "namespace" {
  type        = string
  default     = ""
  description = "Namespace, which could be your organization name, e.g. 'eg' or 'cp'"
}

variable "name" {
  type        = string
  # default     = ""
  description = "CodeBuild name"
}

variable "codePipeline_name" {
  type        = string
  description = "Codepipeline Name"
}

variable "stage" {
  type        = string
  default     = ""
  description = "Stage, e.g. 'prod', 'staging', 'dev', or 'test'"
}

variable "attributes" {
  type        = list(string)
  default     = []
  description = "Additional attributes (e.g. `policy` or `role`)"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags (e.g. `map('BusinessUnit', 'XYZ')`"
}

variable "codebuild_enabled" {
  type        = bool
  default     = true
  description = "A boolean to enable/disable resource creation"
}

variable "environment_variables" {
  type = list(object(
    {
      name  = string
      value = string
      type  = string
  }))

  default = [
    {
      name  = "NO_ADDITIONAL_BUILD_VARS"
      value = "TRUE"
      type  = "PLAINTEXT"
  }]

  description = "A list of maps, that contain the keys 'name', 'value', and 'type' to be used as additional environment variables for the build. Valid types are 'PLAINTEXT', 'PARAMETER_STORE', or 'SECRETS_MANAGER'"
}

variable "description" {
  type        = string
  default     = "Managed by Terraform"
  description = "Short description of the CodeBuild project"
}

variable "concurrent_build_limit" {
  type        = number
  default     = null
  description = "Specify a maximum number of concurrent builds for the project. The value specified must be greater than 0 and less than the account concurrent running builds limit."
}

variable "cache_expiration_days" {
  default     = 7
  description = "How many days should the build cache be kept. It only works when cache_type is 'S3'"
}

variable "cache_bucket_suffix_enabled" {
  type        = bool
  default     = true
  description = "The cache bucket generates a random 13 character string to generate a unique bucket name. If set to false it uses terraform-null-label's id value. It only works when cache_type is 'S3"
}

variable "cache_type" {
  type        = string
  default     = "NO_CACHE"
  description = "The type of storage that will be used for the AWS CodeBuild project cache. Valid values: NO_CACHE, LOCAL, and S3.  Defaults to NO_CACHE.  If cache_type is S3, it will create an S3 bucket for storing codebuild cache inside"
}

variable "local_cache_modes" {
  type        = list(string)
  default     = []
  description = "Specifies settings that AWS CodeBuild uses to store and reuse build dependencies. Valid values: LOCAL_SOURCE_CACHE, LOCAL_DOCKER_LAYER_CACHE, and LOCAL_CUSTOM_CACHE"
}

variable "badge_enabled" {
  type        = bool
  default     = false
  description = "Generates a publicly-accessible URL for the projects build badge. Available as badge_url attribute when enabled"
}

variable "build_image" {
  type        = string
  default     = "aws/codebuild/standard:2.0"
  description = "Docker image for build environment, e.g. 'aws/codebuild/standard:2.0' or 'aws/codebuild/eb-nodejs-6.10.0-amazonlinux-64:4.0.0'. For more info: http://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref.html"
}

variable "build_compute_type" {
  type        = string
  default     = "BUILD_GENERAL1_SMALL"
  description = "Instance type of the build instance"
}

variable "build_timeout" {
  default     = 60
  description = "How long in minutes, from 5 to 480 (8 hours), for AWS CodeBuild to wait until timing out any related build that does not get marked as completed"
}

variable "build_type" {
  type        = string
  default     = "LINUX_CONTAINER"
  description = "The type of build environment, e.g. 'LINUX_CONTAINER' or 'WINDOWS_CONTAINER'"
}

variable "buildspec" {
  type        = string
  default     = ""
  description = "Optional buildspec declaration to use for building the project"
}

variable "privileged_mode" {
  type        = bool
  default     = false
  description = "(Optional) If set to true, enables running the Docker daemon inside a Docker container on the CodeBuild instance. Used when building Docker images"
}

variable "github_token" {
  type        = string
  default     = ""
  description = "(Optional) GitHub auth token environment variable (`GITHUB_TOKEN`)"
}

variable "github_token_type" {
  type        = string
  default     = "PLAINTEXT"
  description = "Storage type of GITHUB_TOKEN environment variable (`PARAMETER_STORE`, `PLAINTEXT`, `SECRETS_MANAGER`)"
}

variable "dockerhub_username" {
  type        = string
  default     = ""
  description = "(Optional) Dockerhub username"
}

variable "dockerhub_password" {
  type        = string
  default     = ""
  description = "(Optional) Dockerhub password"
}

variable "aws_region" {
  type        = string
  default     = ""
  description = "(Optional) AWS Region, e.g. us-east-1. Used as CodeBuild ENV variable when building Docker images. For more info: http://docs.aws.amazon.com/codebuild/latest/userguide/sample-docker.html"
}

variable "aws_account_id" {
  type        = string
  default     = ""
  description = "(Optional) AWS Account ID. Used as CodeBuild ENV variable when building Docker images. For more info: http://docs.aws.amazon.com/codebuild/latest/userguide/sample-docker.html"
}

variable "image_repo_name" {
  type        = string
  default     = "UNSET"
  description = "(Optional) ECR repository name to store the Docker image built by this module. Used as CodeBuild ENV variable when building Docker images. For more info: http://docs.aws.amazon.com/codebuild/latest/userguide/sample-docker.html"
}

/*variable "image_tag" {
  type        = string
  default     = "latest"
  description = "(Optional) Docker image tag in the ECR repository, e.g. 'latest'. Used as CodeBuild ENV variable when building Docker images. For more info: http://docs.aws.amazon.com/codebuild/latest/userguide/sample-docker.html"
}*/

variable "secondary_sources" {
  type = list(object(
    {
      git_clone_depth     = number
      location            = string
      source_identifier   = string
      type                = string
      fetch_submodules    = bool
      insecure_ssl        = bool
      report_build_status = bool
  }))
  default     = []
  description = "(Optional) secondary source for the codebuild project in addition to the primary location"
}

variable "source_type" {
  type        = string
  default     = "CODEPIPELINE"
  description = "The type of repository that contains the source code to be built. Valid values for this parameter are: CODECOMMIT, CODEPIPELINE, GITHUB, GITHUB_ENTERPRISE, BITBUCKET or S3"
}

variable "source_location" {
  type        = string
  default     = ""
  description = "The location of the source code from git or s3"
}

variable "artifact_type" {
  type        = string
  default     = "CODEPIPELINE"
  description = "The build output artifact's type. Valid values for this parameter are: CODEPIPELINE, NO_ARTIFACTS or S3"
}

variable "artifact_location" {
  type        = string
  default     = ""
  description = "Location of artifact. Applies only for artifact of type S3"
}

variable "secondary_artifact_location" {
  type        = string
  default     = null
  description = "Location of secondary artifact. Must be an S3 reference"
}

variable "secondary_artifact_identifier" {
  type        = string
  default     = null
  description = "Secondary artifact identifier. Must match the identifier in the build spec"
}

variable "secondary_artifact_encryption_enabled" {
  type        = bool
  default     = false
  description = "Set to true to enable encryption on the secondary artifact bucket"
}

variable "report_build_status" {
  type        = bool
  default     = false
  description = "Set to true to report the status of a build's start and finish to your source provider. This option is only valid when the source_type is BITBUCKET or GITHUB"
}

variable "git_clone_depth" {
  type        = number
  default     = null
  description = "Truncate git history to this many commits."
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

variable "source_version" {
  type        = string
  default     = ""
  description = "A version of the build input to be built for this project. If not specified, the latest version is used."
}

variable "fetch_git_submodules" {
  type        = bool
  default     = false
  description = "If set to true, fetches Git submodules for the AWS CodeBuild build project."
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project#vpc_config
variable "vpc_config" {
  type        = any
  default     = {}
  description = "Configuration for the builds to run inside a VPC."
}

variable "logs_config" {
  type        = any
  default     = {}
  description = "Configuration for the builds to store log data to CloudWatch or S3."
}

variable "extra_permissions" {
  type        = list(any)
  default     = []
  description = "List of action strings which will be added to IAM service account permissions."
}

variable "encryption_enabled" {
  type        = bool
  default     = false
  description = "When set to 'true' the resource will have AES256 encryption enabled by default"
}

variable "versioning_enabled" {
  type        = bool
  default     = true
  description = "A state of versioning. Versioning is a means of keeping multiple variants of an object in the same bucket"
}

variable "access_log_bucket_name" {
  type        = string
  default     = ""
  description = "Name of the S3 bucket where s3 access log will be sent to"
}

variable "webhook_enabled" {
  type    = bool
  default = false
}

variable "webhook_build_type" {
  type    = string
  default = "BUILD"
}

variable "webhook_filters" {
  type = list(object(
    {
      type    = string
      pattern = string
  }))

  default = []

  description = "A list of maps, that contain the keys 'type', and 'pattern' to be used as webhook filter for the build. Valid types are 'EVENT', 'BASE_REF', 'HEAD_REF', 'ACTOR_ACCOUNT_ID', 'FILE_PATH', 'COMMIT_MESSAGE'. Valid patterns are 'PUSH', 'PULL_REQUEST_CREATED', 'PULL_REQUEST_UPDATED', 'PULL_REQUEST_REOPENED', 'PULL_REQUEST_MERGED'"
}

variable "codepipeline_enabled" {
  type        = bool
  default     = false
  description = "A boolean to enable/disable resource creation"
}

variable "codestar_connection_arn" {
  type        = string
  default     = ""
  description = "The ARN of the CodeStar connection to GitHUb for use in CodePipeline"
}

variable "artifact_store_id" {
  type        = string
  default     = ""
  description = "The name of the S3 bucket to store source artifacts for the pipeline"
}

variable "input_artifacts" {}

variable "artifact_store_arn" {
  type        = string
  default     = ""
  description = "The ARN of the S3 bucket to store source artifacts for the pipeline"
}

variable "slack_notification_sns_topic_arn" {
  type        = string
  default     = ""
  description = "The ARN of the SNS Topic that will use Lambda to send a Slack Notification for the build/pipeline"
}

variable "slack_notification_channel" {
  type        = string
  default     = ""
  description = "Slack Channel Name to tag CodeBuild or CodePipeline and send build event notification messages"
}

variable "environment" {
  type        = string
  description = "A descriptive name for the environment for the AWS Account (e.g. central, dev, prod)"
}

#ECS Prod Variable
variable "ecs_cluster_name" {}
variable "ecs_cluster_service" {}
variable "ecs_file_name" {}
variable "approve_sns_arn" {}
variable "prod_env" {}
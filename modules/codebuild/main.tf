data "aws_caller_identity" "default" {
}

data "aws_region" "default" {
}

resource "aws_s3_bucket" "cache_bucket" {
  #bridgecrew:skip=BC_AWS_S3_13:Skipping `Enable S3 Bucket Logging` check until bridgecrew will support dynamic blocks (https://github.com/bridgecrewio/checkov/issues/776).
  #bridgecrew:skip=BC_AWS_S3_14:Skipping `Ensure all data stored in the S3 bucket is securely encrypted at rest` check until bridgecrew will support dynamic blocks (https://github.com/bridgecrewio/checkov/issues/776).
  #bridgecrew:skip=CKV_AWS_52:Skipping `Ensure S3 bucket has MFA delete enabled` due to issue in terraform (https://github.com/hashicorp/terraform-provider-aws/issues/629).
  count  = var.codebuild_enabled && local.s3_cache_enabled ? 1 : 0
  bucket = local.cache_bucket_name_normalised
  #acl           = "private"
  force_destroy = true
  tags          = var.tags

  /*versioning {
    enabled = var.versioning_enabled
  }

  dynamic "logging" {
    for_each = var.access_log_bucket_name != "" ? [1] : []
    content {
      target_bucket = var.access_log_bucket_name
      target_prefix = "logs/${var.namespace}/"
    }
  }

  lifecycle_rule {
    id      = "codebuildcache"
    enabled = true

    prefix = "/"
    tags   = var.tags

    expiration {
      days = var.cache_expiration_days
    }
  }

  dynamic "server_side_encryption_configuration" {
    for_each = var.encryption_enabled ? ["true"] : []

    content {
      rule {
        apply_server_side_encryption_by_default {
          sse_algorithm = "AES256"
        }
      }
    }
  }*/
}

resource "random_string" "bucket_prefix" {
  count   = var.codebuild_enabled ? 1 : 0
  length  = 12
  number  = false
  upper   = false
  special = false
  lower   = true
}

locals {
  cache_bucket_name = "${var.name}${var.cache_bucket_suffix_enabled ? "-${join("", random_string.bucket_prefix.*.result)}" : ""}"

  ## Clean up the bucket name to use only hyphens, and trim its length to 63 characters.
  ## As per https://docs.aws.amazon.com/AmazonS3/latest/dev/BucketRestrictions.html
  cache_bucket_name_normalised = substr(
    join("-", split("_", lower(local.cache_bucket_name))),
    0,
    min(length(local.cache_bucket_name), 63),
  )

  s3_cache_enabled = var.cache_type == "S3"

  ## This is the magic where a map of a list of maps is generated
  ## and used to conditionally add the cache bucket option to the
  ## aws_codebuild_project
  cache_options = {
    "S3" = {
      type     = "S3"
      location = var.codebuild_enabled && local.s3_cache_enabled ? join("", aws_s3_bucket.cache_bucket.*.bucket) : "none"

    },
    "LOCAL" = {
      type  = "LOCAL"
      modes = var.local_cache_modes
    },
    "NO_CACHE" = {
      type = "NO_CACHE"
    }
  }

  # Final Map Selected from above
  cache = local.cache_options[var.cache_type]
}

resource "aws_iam_role" "default" {
  count                 = var.codebuild_enabled ? 1 : 0
  name                  = "${var.name}-${var.aws_region}"
  assume_role_policy    = data.aws_iam_policy_document.role.json
  force_detach_policies = true
  tags                  = var.tags
}

data "aws_iam_policy_document" "role" {
  statement {
    sid = ""

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }

    effect = "Allow"
  }
}

resource "aws_iam_policy" "default" {
  count  = var.codebuild_enabled ? 1 : 0
  name   = "${var.name}-${var.aws_region}"
  path   = "/service-role/"
  policy = data.aws_iam_policy_document.combined_permissions.json
}

resource "aws_iam_policy" "default_cache_bucket" {
  count = var.codebuild_enabled && local.s3_cache_enabled ? 1 : 0


  name   = "${var.name}-${var.aws_region}-cache-bucket"
  path   = "/service-role/"
  policy = join("", data.aws_iam_policy_document.permissions_cache_bucket.*.json)
}

data "aws_s3_bucket" "secondary_artifact" {
  count  = var.codebuild_enabled ? (var.secondary_artifact_location != null ? 1 : 0) : 0
  bucket = var.secondary_artifact_location
}

data "aws_iam_policy_document" "permissions" {
  count = var.codebuild_enabled ? 1 : 0

  statement {
    sid = ""

    actions = compact(concat([
      "codecommit:GitPull",
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:GetAuthorizationToken",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecs:RunTask",
      "iam:PassRole",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "ssm:GetParameters",
      "secretsmanager:GetSecretValue",
      //TODO: review if following is acceptable to do for specific need.
      "codebuild:CreateReportGroup",
      "codebuild:CreateReport",
      "codebuild:UpdateReport",
      "codebuild:BatchPutTestCases",
      "codebuild:BatchPutCodeCoverages",
      "ecr:BatchGetImage",
      "ecr:DescribeImages"
    ], var.extra_permissions))

    effect = "Allow"

    resources = [
      "*",
    ]
  }

  dynamic "statement" {
    for_each = var.secondary_artifact_location != null ? [1] : []
    content {
      sid = ""

      actions = [
        "s3:PutObject",
        "s3:GetBucketAcl",
        "s3:GetBucketLocation"
      ]

      effect = "Allow"

      resources = [
        join("", data.aws_s3_bucket.secondary_artifact.*.arn),
        "${join("", data.aws_s3_bucket.secondary_artifact.*.arn)}/*",
      ]
    }
  }
}

data "aws_iam_policy_document" "permissions_pipeline_bucket" {
  count = var.codebuild_enabled && var.codepipeline_enabled ? 1 : 0

  statement {
    sid = ""

    actions = [
      "s3:*",
    ]

    effect = "Allow"

    resources = [
      var.artifact_store_arn,
      "${var.artifact_store_arn}/*",
    ]
  }
}

data "aws_iam_policy_document" "vpc_permissions" {
  count = var.codebuild_enabled && var.vpc_config != {} ? 1 : 0

  statement {
    sid = ""

    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeDhcpOptions",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeVpcs"
    ]

    resources = [
      "*",
    ]
  }

  statement {
    sid = ""

    actions = [
      "ec2:CreateNetworkInterfacePermission"
    ]

    resources = [
      "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:network-interface/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "ec2:Subnet"
      values = formatlist(
        "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:subnet/%s",
        var.vpc_config.subnets
      )
    }

    condition {
      test     = "StringEquals"
      variable = "ec2:AuthorizedService"
      values = [
        "codebuild.amazonaws.com"
      ]
    }

  }
}

data "aws_iam_policy_document" "combined_permissions" {
  override_policy_documents = compact([
    join("", data.aws_iam_policy_document.permissions.*.json),
    join("", data.aws_iam_policy_document.permissions_pipeline_bucket.*.json),
    var.vpc_config != {} ? join("", data.aws_iam_policy_document.vpc_permissions.*.json) : null
  ])
}

data "aws_iam_policy_document" "permissions_cache_bucket" {
  count = var.codebuild_enabled && local.s3_cache_enabled ? 1 : 0
  statement {
    sid = ""

    actions = [
      "s3:*",
    ]

    effect = "Allow"

    resources = [
      join("", aws_s3_bucket.cache_bucket.*.arn),
      "${join("", aws_s3_bucket.cache_bucket.*.arn)}/*",
    ]
  }
}

resource "aws_iam_role_policy_attachment" "default" {
  count      = var.codebuild_enabled ? 1 : 0
  policy_arn = join("", aws_iam_policy.default.*.arn)
  role       = join("", aws_iam_role.default.*.id)
}

resource "aws_iam_role_policy_attachment" "default_cache_bucket" {
  count      = var.codebuild_enabled && local.s3_cache_enabled ? 1 : 0
  policy_arn = join("", aws_iam_policy.default_cache_bucket.*.arn)
  role       = join("", aws_iam_role.default.*.id)
}

resource "aws_codebuild_webhook" "default" {
  count        = var.codebuild_enabled && var.webhook_enabled && (var.aws_region != "us-east-1") ? 1 : 0
  project_name = aws_codebuild_project.default[count.index].name
  build_type   = var.webhook_build_type
  filter_group {
    dynamic "filter" {
      for_each = var.webhook_filters
      content {
        type    = filter.value.type
        pattern = filter.value.pattern
      }
    }
  }
}

resource "aws_codebuild_project" "default" {
  count                  = var.codebuild_enabled ? 1 : 0
  name                   = var.name
  description            = var.description
  concurrent_build_limit = var.concurrent_build_limit
  service_role           = join("", aws_iam_role.default.*.arn)
  badge_enabled          = var.badge_enabled
  build_timeout          = var.build_timeout
  source_version         = var.source_version != "" ? var.source_version : null

  tags = merge(
    {
      for name, value in var.tags :
      name => value
      if length(value) > 0
    },
    var.slack_notification_channel == "" ? {} : {
      slack_notification_channel = var.slack_notification_channel
    }
  )

  artifacts {
    type     = var.artifact_type
    location = var.artifact_location
  }

  # Since the output type is restricted to S3 by the provider (this appears to
  # be an bug in AWS, rather than an architectural decision; see this issue for
  # discussion: https://github.com/hashicorp/terraform-provider-aws/pull/9652),
  # this cannot be a CodePipeline output. Otherwise, _all_ of the artifacts
  # would need to be secondary if there were more than one. For reference, see
  # https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-CodeBuild.html#action-reference-CodeBuild-config.
  dynamic "secondary_artifacts" {
    for_each = var.secondary_artifact_location != null ? [1] : []
    content {
      type                = "S3"
      location            = var.secondary_artifact_location
      artifact_identifier = var.secondary_artifact_identifier
      encryption_disabled = !var.secondary_artifact_encryption_enabled
      # According to AWS documention, in order to have the artifacts written
      # to the root of the bucket, the 'namespace_type' should be 'NONE'
      # (which is the default), 'name' should be '/', and 'path' should be
      # empty. For reference, see https://docs.aws.amazon.com/codebuild/latest/APIReference/API_ProjectArtifacts.html.
      # However, I was unable to get this to deploy to the root of the bucket
      # unless path was also set to '/'.
      path = "/"
      name = "/"
    }
  }

  cache {
    type     = lookup(local.cache, "type", null)
    location = lookup(local.cache, "location", null)
    modes    = lookup(local.cache, "modes", null)
  }

  environment {
    compute_type    = var.build_compute_type
    image           = var.build_image
    type            = var.build_type
    privileged_mode = var.privileged_mode

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = signum(length(var.aws_region)) == 1 ? var.aws_region : data.aws_region.default.name
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = signum(length(var.aws_account_id)) == 1 ? var.aws_account_id : data.aws_caller_identity.default.account_id
    }

    dynamic "environment_variable" {
      for_each = signum(length(var.image_repo_name)) == 1 ? [""] : []
      content {
        name  = "IMAGE_REPO_NAME"
        value = var.image_repo_name
      }
    }

    /*dynamic "environment_variable" {
      for_each = signum(length(var.image_tag)) == 1 ? [""] : []
      content {
        name  = "IMAGE_TAG"
        value = var.image_tag
      }
    }*/

    dynamic "environment_variable" {
      for_each = signum(length(var.stage)) == 1 ? [""] : []
      content {
        name  = "STAGE"
        value = var.stage
      }
    }

    dynamic "environment_variable" {
      for_each = signum(length(var.github_token)) == 1 ? [""] : []
      content {
        name  = "GH_TOKEN"
        value = var.github_token
        type  = var.github_token_type
      }
    }

    dynamic "environment_variable" {
      for_each = signum(length(var.dockerhub_username)) == 1 ? [""] : []
      content {
        name  = "DOCKERHUB_USERNAME"
        value = var.dockerhub_username
        type  = "PLAINTEXT"
      }
    }

    dynamic "environment_variable" {
      for_each = signum(length(var.dockerhub_password)) == 1 ? [""] : []
      content {
        name  = "DOCKERHUB_PASSWORD"
        value = var.dockerhub_password
        type  = "PLAINTEXT"
      }
    }

    dynamic "environment_variable" {
      for_each = var.environment_variables
      content {
        name  = environment_variable.value.name
        value = environment_variable.value.value
        type  = environment_variable.value.type
      }
    }
  }

  source {
    buildspec           = var.buildspec
    type                = var.source_type
    location            = var.source_location
    report_build_status = var.report_build_status
    git_clone_depth     = var.git_clone_depth != null ? var.git_clone_depth : null

    dynamic "git_submodules_config" {
      for_each = var.fetch_git_submodules ? [""] : []
      content {
        fetch_submodules = true
      }
    }
  }

  dynamic "secondary_sources" {
    for_each = var.secondary_sources
    content {
      git_clone_depth     = secondary_source.value.git_clone_depth
      location            = secondary_source.value.location
      source_identifier   = secondary_source.value.source_identifier
      type                = secondary_source.value.type
      insecure_ssl        = secondary_source.value.insecure_ssl
      report_build_status = secondary_source.value.report_build_status

      git_submodules_config {
        fetch_submodules = secondary_source.value.fetch_submodules
      }
    }
  }

  dynamic "vpc_config" {
    for_each = length(var.vpc_config) > 0 ? [""] : []
    content {
      vpc_id             = lookup(var.vpc_config, "vpc_id", null)
      subnets            = lookup(var.vpc_config, "subnets", null)
      security_group_ids = lookup(var.vpc_config, "security_group_ids", null)
    }
  }

  dynamic "logs_config" {
    for_each = length(var.logs_config) > 0 ? [""] : []
    content {
      dynamic "cloudwatch_logs" {
        for_each = contains(keys(var.logs_config), "cloudwatch_logs") ? { key = var.logs_config["cloudwatch_logs"] } : {}
        content {
          status      = lookup(cloudwatch_logs.value, "status", null)
          group_name  = lookup(cloudwatch_logs.value, "group_name", null)
          stream_name = lookup(cloudwatch_logs.value, "stream_name", null)
        }
      }

      dynamic "s3_logs" {
        for_each = contains(keys(var.logs_config), "s3_logs") ? { key = var.logs_config["s3_logs"] } : {}
        content {
          status              = lookup(s3_logs.value, "status", null)
          location            = lookup(s3_logs.value, "location", null)
          encryption_disabled = lookup(s3_logs.value, "encryption_disabled", null)
        }
      }
    }
  }
}

#########################################################################################################################
#         Pipeline to use instead of WebHooks
#########################################################################################################################
module "codepipeline" {
  count  = var.codepipeline_enabled ? 1 : 0
  source = "./codepipeline"

  name                       = var.name
  source_location_trimmed    = trimsuffix(trimprefix(var.source_location, "https://github.com/"), ".git")
  source_version             = var.source_version
  codestar_connection_arn    = var.codestar_connection_arn
  artifact_store_id          = var.artifact_store_id
  aws_region                 = signum(length(var.aws_region)) == 1 ? var.aws_region : data.aws_region.default.name
  slack_notification_channel = var.slack_notification_channel
  tags                       = var.tags
}

#########################################################################################################################
#         Slack Notifications
#########################################################################################################################
resource "aws_codestarnotifications_notification_rule" "codebuild_notification_rule" {
  count          = var.slack_notification_channel != "" ? 1 : 0
  detail_type    = "FULL"
  event_type_ids = ["codebuild-project-build-state-failed", "codebuild-project-build-state-succeeded"]

  name     = "bnr-${var.name}-${var.aws_region}"
  resource = aws_codebuild_project.default[count.index].arn

  target {
    address = var.slack_notification_sns_topic_arn
  }
}

resource "aws_codestarnotifications_notification_rule" "codepipeline_notification_rule" {
  count          = var.slack_notification_channel != "" && var.codepipeline_enabled ? 1 : 0
  detail_type    = "FULL"
  event_type_ids = ["codepipeline-pipeline-pipeline-execution-failed", "codepipeline-pipeline-pipeline-execution-canceled", "codepipeline-pipeline-pipeline-execution-started", "codepipeline-pipeline-pipeline-execution-succeeded", "codepipeline-pipeline-pipeline-execution-superseded"]

  name     = "pnr-${var.name}-${var.aws_region}"
  resource = module.codepipeline[count.index].pipeline_arn

  target {
    address = var.slack_notification_sns_topic_arn
  }
}

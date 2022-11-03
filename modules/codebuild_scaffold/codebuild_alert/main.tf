#Secrets
resource "aws_secretsmanager_secret" "lambda_secret" {
  name = "${var.environment}/secrets-${var.aws_region}"
}

resource "aws_secretsmanager_secret_version" "lambda_secret-value" {
  secret_id = aws_secretsmanager_secret.lambda_secret.id

  secret_string = <<EOF
  {
    "GH_USERNAME": "${var.source_credential_user_name}",
    "GH_TOKEN":  "${var.source_credential_token}",
    "SLACK_TOKEN": "${var.slack_token}",
    "SLACK_EMAIL_DOMAIN_FILTER": "${var.slack_email_domain_filter}"
  }
EOF
}

resource "aws_iam_policy" "lambda_logging_policy" {
  name        = "lambda-logging-${var.environment}-${var.aws_region}"
  path        = "/"
  description = "Allows lambda to log"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:PutMetricFilter",
          "logs:PutRetentionPolicy"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}


resource "aws_iam_policy" "lambda_secrets_access" {
  name        = "lambda-secrets-access-${var.environment}-${var.aws_region}"
  path        = "/"
  description = "Allows access to lambda secret for fde"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:ListSecretVersionIds",
          "secretsmanager:GetSecretValue",
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:DescribeSecret",
        ]
        Effect   = "Allow"
        Resource = "${aws_secretsmanager_secret.lambda_secret.arn}"
      },
      {
        Action = [
          "secretsmanager:ListSecrets",
          "secretsmanager:GetRandomPassword"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_pipeline_access" {
  name        = "lambda-pipeline-access-${var.environment}-${var.aws_region}"
  path        = "/"
  description = "Allows lambda to lookup pipeline info"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "codepipeline:Lis*",
          "codepipeline:Get*"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_build_access" {
  name        = "lambda-build-access-${var.environment}-${var.aws_region}"
  path        = "/"
  description = "Allows lambda to lookup codebuild info"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "codebuild:List*",
          "codebuild:BatchGet*"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

module "sns-success-feedback-role" {
  source             = "../iam/role"
  name               = "sns-success-feedback-role-${var.environment}-${var.aws_region}"
  trust_relationship = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "sns.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
  attached_policies  = [aws_iam_policy.lambda_logging_policy.arn]
}

module "sns-failure-feedback-role" {
  source             = "../iam/role"
  name               = "sns-failure-feedback-role-${var.environment}-${var.aws_region}"
  trust_relationship = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "sns.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
  attached_policies  = [aws_iam_policy.lambda_logging_policy.arn]
}

module "lambda-role" {
  source             = "../iam/role"
  name               = "lambda-execution-role-${var.environment}-${var.aws_region}"
  trust_relationship = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
  attached_policies = [aws_iam_policy.lambda_logging_policy.arn,
    aws_iam_policy.lambda_secrets_access.arn,
    aws_iam_policy.lambda_pipeline_access.arn,
    aws_iam_policy.lambda_build_access.arn,
  ]
}

resource "aws_sns_topic" "sns" {
  name                                = "notify-slack-${var.environment}-${var.aws_region}"
  lambda_failure_feedback_role_arn    = module.sns-failure-feedback-role.role_arn
  lambda_success_feedback_role_arn    = module.sns-success-feedback-role.role_arn
  lambda_success_feedback_sample_rate = 100
}

data "aws_iam_policy_document" "sns_topic_policy" {
  policy_id = "__default_policy_ID"

  statement {
    actions = ["sns:Publish"]

    principals {
      type        = "Service"
      identifiers = ["codestar-notifications.amazonaws.com"]
    }
    effect = "Allow"

    resources = [aws_sns_topic.sns.arn]

    sid = "CodeNotification_publish"
  }
}

resource "aws_sns_topic_policy" "default" {
  arn = aws_sns_topic.sns.arn

  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/init/src"
  output_path = "${path.module}/init/target/deploy.zip"
}

resource "aws_lambda_function" "project-notification" {
  filename         = "${path.module}/init/target/deploy.zip"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  description      = "${var.environment} function to alert to slack"
  function_name    = "codebuild-alerts-${var.environment}-${var.aws_region}"
  role             = module.lambda-role.role_arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  timeout          = 120

  environment {
    variables = {
      SECRETS_ARN = "${aws_secretsmanager_secret.lambda_secret.arn}"
    }
  }
}

resource "aws_sns_topic_subscription" "project-notification" {
  topic_arn = aws_sns_topic.sns.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.project-notification.arn
}

resource "aws_lambda_permission" "project-notification" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.project-notification.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.sns.arn
}

locals {
  attached_policies_count = length(var.attached_policies) > var.attached_policies_count ? length(var.attached_policies) : var.attached_policies_count
  inline_policies_count   = length(var.inline_policies) > var.inline_policies_count ? length(var.inline_policies) : var.inline_policies_count
}

variable "name" {
}

variable "trust_relationship" {
}

variable "attached_policies" {
  type = list(string)

  default = []
}

# This is only needed when passing in a policy list with a calculated value
variable "attached_policies_count" {
  default = 0
}

variable "inline_policies" {
  type = map(string)

  default = {}
}

variable "inline_policies_count" {
  default = 0
}

resource "aws_iam_role" "main" {
  name               = var.name
  assume_role_policy = var.trust_relationship
}

resource "aws_iam_role_policy_attachment" "main" {
  count      = local.attached_policies_count
  role       = aws_iam_role.main.name
  policy_arn = var.attached_policies[count.index]
}

resource "aws_iam_role_policy" "main" {
  count  = local.inline_policies_count
  name   = element(keys(var.inline_policies), count.index)
  role   = aws_iam_role.main.name
  policy = element(values(var.inline_policies), count.index)
}

output "role_arn" {
  value = aws_iam_role.main.arn
}

output "role_name" {
  value = aws_iam_role.main.name
}


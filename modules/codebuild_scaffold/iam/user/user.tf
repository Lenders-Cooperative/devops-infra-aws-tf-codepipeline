variable "name" {}

variable "attached_policies" {
  type = list(string)

  default = []
}

variable "inline_policies" {
  type = map(string)

  default = {}
}

variable "inline_policies_count" {
  default = 0
}

resource "aws_iam_user" "main" {
  name = var.name
}

resource "aws_iam_user_policy_attachment" "main" {
  count      = length(var.attached_policies)
  user       = aws_iam_user.main.name
  policy_arn = var.attached_policies[count.index]
}

resource "aws_iam_user_policy" "main" {
  count  = var.inline_policies_count
  name   = element(keys(var.inline_policies), count.index)
  user   = aws_iam_user.main.name
  policy = element(values(var.inline_policies), count.index)
}

output "unique_id" {
  value = aws_iam_user.main.unique_id
}

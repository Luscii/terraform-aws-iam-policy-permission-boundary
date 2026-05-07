module "label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  namespace   = "example"
  environment = "production"
  stage       = "prd"
  name        = "workload-boundary"
  attributes  = ["complete"]

  tags = {
    ManagedBy = "Terraform"
    Purpose   = "WorkloadPermissionBoundary"
  }
}

module "example" {
  source = "../../"

  name    = module.label.name
  context = module.label.context

  # Workload-shaped allow list — qualified actions across the
  # services a typical ECS Fargate workload reaches for. Bare
  # service wildcards (`iam:*`, `*`) are rejected by validation.
  allowed_actions = [
    "s3:*",
    "dynamodb:*",
    "sqs:*",
    "sns:*",
    "ec2:Describe*",
    "ecs:Describe*",
    "kms:Decrypt",
    "kms:Encrypt",
    "kms:GenerateDataKey",
    "secretsmanager:GetSecretValue",
    "ssm:GetParameter",
    "ssm:GetParameters",
    "logs:CreateLogStream",
    "logs:PutLogEvents",
  ]

  # Caller-supplied additional denies on top of built-ins.
  denied_actions = [
    "ec2:RunInstances",
    "ec2:TerminateInstances",
  ]

  # Built-in denies stay on (defaults). All toggles intentionally
  # omitted to show the safe, opinionated shape.
}

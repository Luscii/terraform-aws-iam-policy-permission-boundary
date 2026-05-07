locals {
  builtin_denies_boundary_tampering = [
    "iam:DeleteRolePermissionsBoundary",
    "iam:DeleteUserPermissionsBoundary",
    "iam:PutRolePermissionsBoundary",
    "iam:PutUserPermissionsBoundary",
  ]

  builtin_denies_policy_mutation = var.permit_policy_mutation ? [] : [
    "iam:UpdateAssumeRolePolicy",
    "iam:CreatePolicyVersion",
    "iam:SetDefaultPolicyVersion",
  ]

  builtin_denies_human_user_surface = var.permit_human_user_actions ? [] : [
    "iam:CreateUser",
    "iam:CreateLoginProfile",
    "iam:UpdateLoginProfile",
    "iam:CreateAccessKey",
    "iam:UpdateAccessKey",
  ]

  builtin_denies_org_governance = var.permit_org_governance ? [] : [
    "organizations:*",
    "account:*",
  ]

  builtin_denies = concat(
    local.builtin_denies_boundary_tampering,
    local.builtin_denies_policy_mutation,
    local.builtin_denies_human_user_surface,
    local.builtin_denies_org_governance,
  )
}

data "aws_iam_policy_document" "this" {
  dynamic "statement" {
    for_each = var.allow_all ? [1] : []

    content {
      sid       = "AllowAll"
      effect    = "Allow"
      actions   = ["*"]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = length(var.allowed_actions) > 0 ? [1] : []

    content {
      sid       = "AllowedActions"
      effect    = "Allow"
      actions   = var.allowed_actions
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = length(var.denied_actions) > 0 ? [1] : []

    content {
      sid       = "DeniedActions"
      effect    = "Deny"
      actions   = var.denied_actions
      resources = ["*"]
    }
  }

  statement {
    sid       = "BuiltInDenies"
    effect    = "Deny"
    actions   = local.builtin_denies
    resources = ["*"]
  }
}

resource "aws_iam_policy" "this" {
  name        = module.label.id
  path        = "/boundaries/"
  description = "Permission boundary policy: ${module.label.name}"
  policy      = data.aws_iam_policy_document.this.json

  tags = module.label.tags

  lifecycle {
    precondition {
      condition     = !(var.allow_all && length(var.allowed_actions) > 0)
      error_message = "allow_all and allowed_actions are mutually exclusive — set allow_all = true for the deny-list PB shape, or supply allowed_actions for an allow-list PB. Not both."
    }
  }
}

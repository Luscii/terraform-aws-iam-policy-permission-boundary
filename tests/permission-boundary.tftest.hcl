# Real provider with skip flags + dummy creds — NOT mock_provider.
# `mock_provider "aws" {}` substitutes locally-computed
# `aws_iam_policy_document.json` with random strings, breaking
# every JSON-shape assertion below.
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

variables {
  name = "test-boundary"
}

run "shape_path_and_statements" {
  command = plan

  variables {
    allowed_actions = ["s3:GetObject"]
    denied_actions  = ["ec2:RunInstances"]
  }

  assert {
    condition     = aws_iam_policy.this.path == "/boundaries/"
    error_message = "Permission boundary policy must be at path /boundaries/"
  }

  assert {
    condition = contains(
      [for s in jsondecode(data.aws_iam_policy_document.this.json).Statement : s.Sid],
      "AllowedActions"
    )
    error_message = "Policy must include AllowedActions statement when allowed_actions is non-empty"
  }

  assert {
    condition = contains(
      [for s in jsondecode(data.aws_iam_policy_document.this.json).Statement : s.Sid],
      "DeniedActions"
    )
    error_message = "Policy must include DeniedActions statement when denied_actions is non-empty"
  }

  assert {
    condition = contains(
      [for s in jsondecode(data.aws_iam_policy_document.this.json).Statement : s.Sid],
      "BuiltInDenies"
    )
    error_message = "Policy must always include BuiltInDenies statement"
  }
}

run "effect_strings_are_correct" {
  command = plan

  variables {
    allowed_actions = ["s3:GetObject"]
    denied_actions  = ["ec2:RunInstances"]
  }

  assert {
    condition = anytrue([
      for s in jsondecode(data.aws_iam_policy_document.this.json).Statement :
      s.Effect == "Allow" if s.Sid == "AllowedActions"
    ])
    error_message = "AllowedActions statement must have Effect = Allow"
  }

  assert {
    condition = anytrue([
      for s in jsondecode(data.aws_iam_policy_document.this.json).Statement :
      s.Effect == "Deny" if s.Sid == "DeniedActions"
    ])
    error_message = "DeniedActions statement must have Effect = Deny"
  }

  assert {
    condition = anytrue([
      for s in jsondecode(data.aws_iam_policy_document.this.json).Statement :
      s.Effect == "Deny" if s.Sid == "BuiltInDenies"
    ])
    error_message = "BuiltInDenies statement must have Effect = Deny"
  }
}

run "boundary_tampering_always_denied" {
  command = plan

  variables {
    allowed_actions = ["s3:GetObject"]
    denied_actions  = []
  }

  # BuiltInDenies has 4+ actions, so Action is always a list — safe to use contains()
  assert {
    condition = anytrue([
      for s in jsondecode(data.aws_iam_policy_document.this.json).Statement :
      contains(s.Action, "iam:DeleteRolePermissionsBoundary") if s.Sid == "BuiltInDenies"
    ])
    error_message = "BuiltInDenies must include iam:DeleteRolePermissionsBoundary"
  }

  assert {
    condition = anytrue([
      for s in jsondecode(data.aws_iam_policy_document.this.json).Statement :
      contains(s.Action, "iam:PutRolePermissionsBoundary") if s.Sid == "BuiltInDenies"
    ])
    error_message = "BuiltInDenies must include iam:PutRolePermissionsBoundary"
  }
}

run "human_user_surface_denied_by_default" {
  command = plan

  variables {
    allowed_actions = ["s3:GetObject"]
    denied_actions  = []
  }

  assert {
    condition = anytrue([
      for s in jsondecode(data.aws_iam_policy_document.this.json).Statement :
      contains(s.Action, "iam:CreateUser") if s.Sid == "BuiltInDenies"
    ])
    error_message = "BuiltInDenies must include iam:CreateUser by default"
  }

  assert {
    condition = anytrue([
      for s in jsondecode(data.aws_iam_policy_document.this.json).Statement :
      contains(s.Action, "iam:CreateAccessKey") if s.Sid == "BuiltInDenies"
    ])
    error_message = "BuiltInDenies must include iam:CreateAccessKey by default"
  }
}

run "org_governance_denied_by_default" {
  command = plan

  variables {
    allowed_actions = ["s3:GetObject"]
    denied_actions  = []
  }

  assert {
    condition = anytrue([
      for s in jsondecode(data.aws_iam_policy_document.this.json).Statement :
      contains(s.Action, "organizations:*") if s.Sid == "BuiltInDenies"
    ])
    error_message = "BuiltInDenies must include organizations:* by default"
  }

  assert {
    condition = anytrue([
      for s in jsondecode(data.aws_iam_policy_document.this.json).Statement :
      contains(s.Action, "account:*") if s.Sid == "BuiltInDenies"
    ])
    error_message = "BuiltInDenies must include account:* by default"
  }
}

run "permit_human_user_actions_removes_those_denies" {
  command = plan

  variables {
    allowed_actions           = ["s3:GetObject"]
    denied_actions            = []
    permit_human_user_actions = true
  }

  assert {
    condition = !anytrue([
      for s in jsondecode(data.aws_iam_policy_document.this.json).Statement :
      contains(s.Action, "iam:CreateUser") if s.Sid == "BuiltInDenies"
    ])
    error_message = "permit_human_user_actions = true must remove iam:CreateUser from BuiltInDenies"
  }

  # Boundary tampering must still be denied
  assert {
    condition = anytrue([
      for s in jsondecode(data.aws_iam_policy_document.this.json).Statement :
      contains(s.Action, "iam:DeleteRolePermissionsBoundary") if s.Sid == "BuiltInDenies"
    ])
    error_message = "Boundary tampering must remain denied even when permit_human_user_actions = true"
  }
}

run "permit_org_governance_removes_those_denies" {
  command = plan

  variables {
    allowed_actions       = ["s3:GetObject"]
    denied_actions        = []
    permit_org_governance = true
  }

  assert {
    condition = !anytrue([
      for s in jsondecode(data.aws_iam_policy_document.this.json).Statement :
      contains(s.Action, "organizations:*") if s.Sid == "BuiltInDenies"
    ])
    error_message = "permit_org_governance = true must remove organizations:* from BuiltInDenies"
  }

  # Human user surface must still be denied (different toggle)
  assert {
    condition = anytrue([
      for s in jsondecode(data.aws_iam_policy_document.this.json).Statement :
      contains(s.Action, "iam:CreateUser") if s.Sid == "BuiltInDenies"
    ])
    error_message = "Human user surface must remain denied when only permit_org_governance is set"
  }
}

run "empty_allowed_actions_skips_allowed_statement" {
  command = plan

  variables {
    allowed_actions = []
    denied_actions  = ["ec2:RunInstances"]
  }

  assert {
    condition = !contains(
      [for s in jsondecode(data.aws_iam_policy_document.this.json).Statement : s.Sid],
      "AllowedActions"
    )
    error_message = "Empty allowed_actions must not produce an AllowedActions statement (empty actions array is invalid IAM)"
  }

  # BuiltInDenies still present
  assert {
    condition = contains(
      [for s in jsondecode(data.aws_iam_policy_document.this.json).Statement : s.Sid],
      "BuiltInDenies"
    )
    error_message = "BuiltInDenies must be present even when allowed_actions is empty"
  }
}

run "empty_denied_actions_skips_denied_statement" {
  command = plan

  variables {
    allowed_actions = ["s3:GetObject"]
    denied_actions  = []
  }

  assert {
    condition = !contains(
      [for s in jsondecode(data.aws_iam_policy_document.this.json).Statement : s.Sid],
      "DeniedActions"
    )
    error_message = "Empty denied_actions must not produce a DeniedActions statement"
  }

  assert {
    condition = contains(
      [for s in jsondecode(data.aws_iam_policy_document.this.json).Statement : s.Sid],
      "BuiltInDenies"
    )
    error_message = "BuiltInDenies must be present even when denied_actions is empty"
  }
}

run "rejects_bare_iam_wildcard_in_allowed" {
  command = plan

  variables {
    allowed_actions = ["iam:*"]
    denied_actions  = []
  }

  expect_failures = [var.allowed_actions]
}

run "rejects_bare_star_in_allowed" {
  command = plan

  variables {
    allowed_actions = ["*"]
    denied_actions  = []
  }

  expect_failures = [var.allowed_actions]
}

run "rejects_organizations_wildcard_in_allowed" {
  command = plan

  variables {
    allowed_actions = ["organizations:*"]
    denied_actions  = []
  }

  expect_failures = [var.allowed_actions]
}

run "allow_all_emits_unrestricted_allow" {
  command = plan

  variables {
    allow_all       = true
    allowed_actions = []
    denied_actions  = ["ec2:RunInstances"]
  }

  assert {
    condition = contains(
      [for s in jsondecode(data.aws_iam_policy_document.this.json).Statement : s.Sid],
      "AllowAll"
    )
    error_message = "allow_all = true must produce an AllowAll statement"
  }

  assert {
    condition = anytrue([
      for s in jsondecode(data.aws_iam_policy_document.this.json).Statement :
      s.Effect == "Allow" && s.Action == "*" && s.Resource == "*" if s.Sid == "AllowAll"
    ])
    error_message = "AllowAll statement must be Effect=Allow, Action=*, Resource=*"
  }

  assert {
    condition = !contains(
      [for s in jsondecode(data.aws_iam_policy_document.this.json).Statement : s.Sid],
      "AllowedActions"
    )
    error_message = "allow_all = true with empty allowed_actions must not produce an AllowedActions statement"
  }

  # Built-in denies still present in deny-list shape
  assert {
    condition = contains(
      [for s in jsondecode(data.aws_iam_policy_document.this.json).Statement : s.Sid],
      "BuiltInDenies"
    )
    error_message = "BuiltInDenies must be present even when allow_all = true"
  }
}

run "allow_all_with_allowed_actions_rejected_by_precondition" {
  command = plan

  variables {
    allow_all       = true
    allowed_actions = ["s3:GetObject"]
    denied_actions  = []
  }

  expect_failures = [aws_iam_policy.this]
}

run "policy_mutation_denied_by_default" {
  command = plan

  variables {
    allowed_actions = ["s3:GetObject"]
    denied_actions  = []
  }

  assert {
    condition = anytrue([
      for s in jsondecode(data.aws_iam_policy_document.this.json).Statement :
      contains(s.Action, "iam:UpdateAssumeRolePolicy") if s.Sid == "BuiltInDenies"
    ])
    error_message = "BuiltInDenies must include iam:UpdateAssumeRolePolicy by default"
  }

  assert {
    condition = anytrue([
      for s in jsondecode(data.aws_iam_policy_document.this.json).Statement :
      contains(s.Action, "iam:CreatePolicyVersion") if s.Sid == "BuiltInDenies"
    ])
    error_message = "BuiltInDenies must include iam:CreatePolicyVersion by default"
  }

  assert {
    condition = anytrue([
      for s in jsondecode(data.aws_iam_policy_document.this.json).Statement :
      contains(s.Action, "iam:SetDefaultPolicyVersion") if s.Sid == "BuiltInDenies"
    ])
    error_message = "BuiltInDenies must include iam:SetDefaultPolicyVersion by default"
  }
}

run "permit_policy_mutation_removes_those_denies" {
  command = plan

  variables {
    allowed_actions        = ["s3:GetObject"]
    denied_actions         = []
    permit_policy_mutation = true
  }

  assert {
    condition = !anytrue([
      for s in jsondecode(data.aws_iam_policy_document.this.json).Statement :
      contains(s.Action, "iam:UpdateAssumeRolePolicy") if s.Sid == "BuiltInDenies"
    ])
    error_message = "permit_policy_mutation = true must remove iam:UpdateAssumeRolePolicy from BuiltInDenies"
  }

  assert {
    condition = !anytrue([
      for s in jsondecode(data.aws_iam_policy_document.this.json).Statement :
      contains(s.Action, "iam:CreatePolicyVersion") if s.Sid == "BuiltInDenies"
    ])
    error_message = "permit_policy_mutation = true must remove iam:CreatePolicyVersion from BuiltInDenies"
  }

  # Boundary tampering remains denied
  assert {
    condition = anytrue([
      for s in jsondecode(data.aws_iam_policy_document.this.json).Statement :
      contains(s.Action, "iam:DeleteRolePermissionsBoundary") if s.Sid == "BuiltInDenies"
    ])
    error_message = "Boundary tampering must remain denied even when permit_policy_mutation = true"
  }
}

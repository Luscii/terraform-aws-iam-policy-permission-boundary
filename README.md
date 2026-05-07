# terraform-aws-iam-policy-permission-boundary

Creates an `aws_iam_policy` shaped as a **Permission Boundary** — a maximum-permission cap that workload roles must carry. The module produces the policy ARN; binding it onto roles is the consumer's responsibility (typically via `permissions_boundary` on `aws_iam_role` or via the `iam:PermissionsBoundary` condition on `iam:CreateRole`).

The module is opinionated: every policy it produces *always* denies a small set of actions that defeat the very purpose of a boundary (boundary tampering, by default also human-user provisioning and org-level governance). Callers add their own allow/deny lists on top.

## When to reach for this module

- You are building a Permission Boundary that bounds the *effective* permissions of a workload role, even when that role is granted broader managed policies.
- You want the boundary's non-negotiable denies enforced *by construction*, not by review convention.
- Your boundary content fits flat allow/deny action lists (this module does not currently expose `NotAction`, `NotResource`, or conditions — see "When not to reach for this module").

## When not to reach for this module

- You need IAM conditions in the boundary (e.g., `aws:RequestedRegion` pinning, recursive `iam:PermissionsBoundary` requirement on role creation). Author the policy directly.
- You need `NotAction` / `NotResource` patterns. Author the policy directly.
- You need per-statement resource scoping. The module hardcodes `Resource: ["*"]`, which is appropriate for boundaries (a boundary caps *what the role can attempt*, not *which resources*) but limits expressiveness.

## Allow-list vs deny-list shape

A Permission Boundary in AWS is the *intersection* of allows: a role's effective permissions are the overlap of its identity-based policies and its boundary. Two shapes are common:

- **Allow-list PB** — the boundary's `Allow` enumerates exactly which actions are permitted. Identity policies grant some subset of those. Use `allowed_actions = [...]`.
- **Deny-list PB** — the boundary's `Allow` is `*` and the caps come entirely from explicit denies (built-in + caller-supplied). Identity policies grant whatever they grant; the boundary subtracts dangerous actions. Use `allow_all = true`.

The two are mutually exclusive — the precondition rejects setting both. Pick the one that matches the role's threat model.

## Built-in denies

These are always present in the rendered policy. They cannot be removed by caller-supplied `denied_actions` (which only adds; it does not subtract).

| Group | Actions | Toggle |
|---|---|---|
| **Boundary tampering** | `iam:DeleteRolePermissionsBoundary`, `iam:DeleteUserPermissionsBoundary`, `iam:PutRolePermissionsBoundary`, `iam:PutUserPermissionsBoundary` | Always on (no opt-out) |
| **Policy / trust mutation** | `iam:UpdateAssumeRolePolicy`, `iam:CreatePolicyVersion`, `iam:SetDefaultPolicyVersion` | Off by default. Set `permit_policy_mutation = true` to permit. |
| **Human user surface** | `iam:CreateUser`, `iam:CreateLoginProfile`, `iam:UpdateLoginProfile`, `iam:CreateAccessKey`, `iam:UpdateAccessKey` | Off by default. Set `permit_human_user_actions = true` to permit. |
| **Org governance** | `organizations:*`, `account:*` | Off by default. Set `permit_org_governance = true` to permit. |

Notably absent from the built-in denies: `iam:CreateRole`. The boundary does *not* deny role creation — that is governed by an upstream condition (`iam:PermissionsBoundary` on `iam:CreateRole`) in the consumer's policy, ensuring any newly created role carries this same boundary.

## Validations

The module fails fast at plan time on inputs that would defeat the boundary:

- `allowed_actions` must not contain `*`, `iam:*`, `sts:*`, `organizations:*`, or `account:*`. Use qualified actions (`iam:Get*`, `s3:GetObject`), or `allow_all = true` for the deny-list shape.
- `allow_all` and a non-empty `allowed_actions` are mutually exclusive.

## Usage

### Deny-list shape (workload PB)

The standard shape for boundaries on workload roles: allow everything, cap via the built-in denies + any caller-supplied denies.

```hcl
module "label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  namespace = "luscii"
  name      = "workload"
}

module "boundary" {
  source = "github.com/Luscii/terraform-aws-iam-policy-permission-boundary?ref=v0.1.0"

  name    = module.label.name
  context = module.label.context

  allow_all = true

  denied_actions = [
    "ec2:RunInstances",
  ]
}
```

### Allow-list shape

For boundaries that should narrow the role to specific services regardless of identity-policy grants.

```hcl
module "boundary" {
  source = "github.com/Luscii/terraform-aws-iam-policy-permission-boundary?ref=v0.1.0"

  name    = module.label.name
  context = module.label.context

  allowed_actions = [
    "s3:*",
    "dynamodb:*",
    "kms:Decrypt",
    "kms:GenerateDataKey",
  ]
}
```

The boundary is then bound onto a role via `permissions_boundary = module.boundary.policy_arn`.

## Examples

- [`examples/basic`](./examples/basic) — minimal allow/deny lists with default built-in denies.
- [`examples/complete`](./examples/complete) — workload-shaped boundary with realistic action lists, tags, and one of the opt-out toggles demonstrated.

## Tests

Unit tests live in [`tests/permission-boundary.tftest.hcl`](./tests/permission-boundary.tftest.hcl). They use a real AWS provider with `skip_credentials_validation` / `skip_requesting_account_id` / `skip_metadata_api_check` set, because `mock_provider "aws" {}` substitutes locally-computed `aws_iam_policy_document.json` with random strings and breaks JSON-shape assertions.

```bash
terraform init
terraform test
```

## Pre-commit

```bash
brew install pre-commit
pre-commit install
pre-commit run --all-files
```

## Configuration

<!-- BEGIN_TF_DOCS -->
<!-- terraform-docs will populate this section -->
<!-- END_TF_DOCS -->

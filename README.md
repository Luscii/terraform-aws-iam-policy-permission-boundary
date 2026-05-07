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
### Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.9 |

### Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.44.0 |

### Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_label"></a> [label](#module\_label) | cloudposse/label/null | 0.25.0 |

### Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy_document.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_allow_all"></a> [allow\_all](#input\_allow\_all) | Emit an unrestricted `Allow *` on `*`. This is the standard shape<br/>for a Permission Boundary configured as a deny-list — the boundary<br/>caps via its built-in + caller-supplied denies; identity-based<br/>policies still grant the actual permissions. Mutually exclusive<br/>with `allowed_actions`: use one or the other. | `bool` | `false` | no |
| <a name="input_allowed_actions"></a> [allowed\_actions](#input\_allowed\_actions) | Allow-list for the Permission Boundary policy.<br/>Use qualified actions (e.g., `iam:Get*`, `s3:GetObject`).<br/>Bare service wildcards that would defeat an allow-list boundary<br/>(`iam:*`, `sts:*`, `organizations:*`, `account:*`, `*`) are rejected<br/>here — for the deny-list PB shape (allow everything, cap via denies),<br/>use `allow_all = true` instead.<br/>May be empty (default) if the boundary is deny-only or uses `allow_all`. | `list(string)` | `[]` | no |
| <a name="input_context"></a> [context](#input\_context) | Single object for setting entire context at once.<br/>See description of individual variables for details.<br/>Leave string and numeric variables as `null` to use default value.<br/>Individual variable settings (non-null) override settings in context object,<br/>except for attributes, tags, and additional\_tag\_map, which are merged. | `any` | <pre>{<br/>  "additional_tag_map": {},<br/>  "attributes": [],<br/>  "delimiter": null,<br/>  "descriptor_formats": {},<br/>  "enabled": true,<br/>  "environment": null,<br/>  "id_length_limit": null,<br/>  "label_key_case": null,<br/>  "label_order": [],<br/>  "label_value_case": null,<br/>  "labels_as_tags": [<br/>    "unset"<br/>  ],<br/>  "name": null,<br/>  "namespace": null,<br/>  "regex_replace_chars": null,<br/>  "stage": null,<br/>  "tags": {},<br/>  "tenant": null<br/>}</pre> | no |
| <a name="input_denied_actions"></a> [denied\_actions](#input\_denied\_actions) | Caller-supplied additional denies, applied on top of the<br/>module's built-in denies. Overlap with built-ins is harmless<br/>(idempotent). May be empty (default). | `list(string)` | `[]` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the resource to be labeled. This is used to generate the label key and value. | `string` | n/a | yes |
| <a name="input_permit_human_user_actions"></a> [permit\_human\_user\_actions](#input\_permit\_human\_user\_actions) | Permit the human-user-surface actions (`iam:CreateUser`,<br/>`iam:CreateLoginProfile`, `iam:UpdateLoginProfile`,<br/>`iam:CreateAccessKey`, `iam:UpdateAccessKey`) that this module<br/>denies by default. Only set to `true` for boundaries on roles<br/>that legitimately manage human users (rare). | `bool` | `false` | no |
| <a name="input_permit_org_governance"></a> [permit\_org\_governance](#input\_permit\_org\_governance) | Permit `organizations:*` and `account:*` that this module denies<br/>by default. Only set to `true` for boundaries on org-management<br/>roles (rare). | `bool` | `false` | no |
| <a name="input_permit_policy_mutation"></a> [permit\_policy\_mutation](#input\_permit\_policy\_mutation) | Permit `iam:UpdateAssumeRolePolicy`, `iam:CreatePolicyVersion`,<br/>and `iam:SetDefaultPolicyVersion` that this module denies by<br/>default. These actions can be used to bypass the boundary<br/>(rewriting trust policies, mutating attached policies in place,<br/>activating older policy versions). Only set to `true` for<br/>boundaries on roles that legitimately manage other roles' trust<br/>policies or policy versions (rare). | `bool` | `false` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_label_context"></a> [label\_context](#output\_label\_context) | Context of the label for subsequent use |
| <a name="output_policy_arn"></a> [policy\_arn](#output\_policy\_arn) | ARN of the Permission Boundary policy |
| <a name="output_policy_document_json"></a> [policy\_document\_json](#output\_policy\_document\_json) | JSON of the Permission Boundary policy document |
<!-- END_TF_DOCS -->

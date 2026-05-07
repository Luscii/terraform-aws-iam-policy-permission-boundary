variable "context" {
  type = any
  default = {
    enabled             = true
    namespace           = null
    tenant              = null
    environment         = null
    stage               = null
    name                = null
    delimiter           = null
    attributes          = []
    tags                = {}
    additional_tag_map  = {}
    regex_replace_chars = null
    label_order         = []
    id_length_limit     = null
    label_key_case      = null
    label_value_case    = null
    descriptor_formats  = {}
    # Note: we have to use [] instead of null for unset lists due to
    # https://github.com/hashicorp/terraform/issues/28137
    # which was not fixed until Terraform 1.0.0,
    # but we want the default to be all the labels in `label_order`
    # and we want users to be able to prevent all tag generation
    # by setting `labels_as_tags` to `[]`, so we need
    # a different sentinel to indicate "default"
    labels_as_tags = ["unset"]
  }
  description = <<-EOT
    Single object for setting entire context at once.
    See description of individual variables for details.
    Leave string and numeric variables as `null` to use default value.
    Individual variable settings (non-null) override settings in context object,
    except for attributes, tags, and additional_tag_map, which are merged.
  EOT

  validation {
    condition     = lookup(var.context, "label_key_case", null) == null ? true : contains(["lower", "title", "upper"], var.context["label_key_case"])
    error_message = "Allowed values: `lower`, `title`, `upper`."
  }

  validation {
    condition     = lookup(var.context, "label_value_case", null) == null ? true : contains(["lower", "title", "upper", "none"], var.context["label_value_case"])
    error_message = "Allowed values: `lower`, `title`, `upper`, `none`."
  }
}

variable "name" {
  type        = string
  description = "Name of the resource to be labeled. This is used to generate the label key and value."
}

variable "allowed_actions" {
  type        = list(string)
  description = <<-EOT
    List of allowed actions for the Permission Boundary policy.
    Use qualified actions (e.g., `iam:Get*`, `s3:GetObject`).
    Bare service wildcards that would defeat the boundary
    (`iam:*`, `sts:*`, `organizations:*`, `account:*`, `*`) are rejected.
    May be empty if the boundary is deny-only.
  EOT

  validation {
    condition = alltrue([
      for action in var.allowed_actions :
      !contains(["*", "iam:*", "sts:*", "organizations:*", "account:*"], lower(action))
    ])
    error_message = "allowed_actions must not contain bare wildcards for iam, sts, organizations, account, or '*' — these defeat the boundary. Use qualified actions like 'iam:Get*' instead."
  }
}

variable "denied_actions" {
  type        = list(string)
  description = <<-EOT
    Caller-supplied additional denies, applied on top of the
    module's built-in denies. Overlap with built-ins is harmless
    (idempotent). May be empty.
  EOT
}

variable "permit_human_user_actions" {
  type        = bool
  default     = false
  description = <<-EOT
    Permit the human-user-surface actions (`iam:CreateUser`,
    `iam:CreateLoginProfile`, `iam:UpdateLoginProfile`,
    `iam:CreateAccessKey`, `iam:UpdateAccessKey`) that this module
    denies by default. Only set to `true` for boundaries on roles
    that legitimately manage human users (rare).
  EOT
}

variable "permit_org_governance" {
  type        = bool
  default     = false
  description = <<-EOT
    Permit `organizations:*` and `account:*` that this module denies
    by default. Only set to `true` for boundaries on org-management
    roles (rare).
  EOT
}

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

  # Workload PB: deny-list shape. Allow everything; identity-based
  # policies grant the actual permissions; the boundary caps via
  # built-in denies (boundary tampering, policy / trust mutation,
  # human user surface, org governance) plus the caller's additional
  # denies below.
  allow_all = true

  # Caller-supplied additional denies on top of built-ins.
  denied_actions = [
    "ec2:RunInstances",
    "ec2:TerminateInstances",
  ]

  # Built-in denies stay on (defaults). All toggles intentionally
  # omitted to show the safe, opinionated workload-PB shape.
}

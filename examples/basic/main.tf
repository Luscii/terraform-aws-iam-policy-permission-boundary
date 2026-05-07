module "label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  namespace   = "example"
  environment = "dev"
  name        = "basic-boundary"
}

module "example" {
  source = "../../"

  name    = module.label.name
  context = module.label.context

  allowed_actions = [
    "s3:GetObject",
    "s3:ListBucket",
  ]

  denied_actions = [
    "ec2:RunInstances",
  ]
}

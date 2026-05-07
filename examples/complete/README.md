# Complete Example

Workload-shaped Permission Boundary with realistic action lists, tags, and the module's full feature surface (including default-on built-in denies).

## What this example demonstrates

- A boundary suitable for an ECS Fargate workload role: broad service access (`s3:*`, `dynamodb:*`, `sqs:*`, `sns:*`, etc.) with qualified read access on EC2/ECS describe APIs and KMS/Secrets/SSM/CloudWatch Logs.
- Caller-supplied additional denies on top of built-ins (`ec2:RunInstances`, `ec2:TerminateInstances`).
- Tags propagated via the CloudPosse label module.
- All built-in deny groups on (boundary tampering, human user surface, org governance) — no toggles overridden.

## What this example does *not* show

- The opt-out toggles (`permit_human_user_actions`, `permit_org_governance`). Those exist for niche boundaries (org-management roles, human-IAM roles) and shouldn't be reached for in a workload context.
- IAM conditions or `NotAction` patterns — the module does not currently expose these.

## Usage

```bash
terraform init
terraform plan
terraform apply
```

## Cleanup

```bash
terraform destroy
```

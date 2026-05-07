# Complete Example

Workload-shaped Permission Boundary in the deny-list shape: `allow_all = true` plus caller-supplied denies, with the module's full default-on built-in denies left intact.

## What this example demonstrates

- The standard workload PB shape: unrestricted Allow combined with built-in denies (boundary tampering, policy / trust mutation, human user surface, org governance) plus caller-supplied additional denies (`ec2:RunInstances`, `ec2:TerminateInstances`).
- Tags propagated via the CloudPosse label module.
- Mutual exclusion with `allowed_actions` — `allow_all` and a non-empty `allowed_actions` would fail at plan time.

## What this example does *not* show

- The opt-out toggles (`permit_policy_mutation`, `permit_human_user_actions`, `permit_org_governance`). Those exist for niche boundaries (policy-managing roles, org-management roles, human-IAM roles) and shouldn't be reached for in a workload context.
- The allow-list shape (`allowed_actions = [...]`). See [`examples/basic`](../basic) for that.
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

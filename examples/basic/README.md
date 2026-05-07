# Basic Example

Minimal Permission Boundary with one allow and one caller-supplied deny. The module's built-in denies (boundary tampering, human user surface, org governance) are present by default — no toggles overridden.

## What this example demonstrates

- Smallest possible boundary: one Allow (`s3:GetObject`, `s3:ListBucket`), one caller Deny (`ec2:RunInstances`).
- All built-in denies on (defaults).
- CloudPosse label integration.

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

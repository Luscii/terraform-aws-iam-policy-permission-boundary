output "label_context" {
  value       = module.label.context
  description = "Context of the label for subsequent use"
}

output "policy_arn" {
  value       = aws_iam_policy.this.arn
  description = "ARN of the Permission Boundary policy"
}

output "policy_document_json" {
  value       = data.aws_iam_policy_document.this.json
  description = "JSON of the Permission Boundary policy document"
}

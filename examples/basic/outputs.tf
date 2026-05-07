output "label_context" {
  value       = module.example.label_context
  description = "Label context from the module"
}

output "policy_arn" {
  value       = module.example.policy_arn
  description = "ARN of the Permission Boundary policy"
}

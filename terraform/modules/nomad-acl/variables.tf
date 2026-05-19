variable "custom_policies" {
  description = "Map of additional ACL policies to create. Key is the policy name."
  type = map(object({
    description = string
    rules_hcl   = string
  }))
  default = {}
}

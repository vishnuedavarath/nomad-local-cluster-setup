variable "jobs" {
  description = "Map of plain job specs to deploy. Key is a logical name, value is the file path."
  type        = map(string)
  default     = {}
}

variable "templated_jobs" {
  description = "Map of templated job specs. Key is a logical name."
  type = map(object({
    template_path = string
    vars          = map(string)
  }))
  default = {}
}

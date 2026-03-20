variable "project_name" {
  description = "Project name prefix for backend resources"
  type        = string
  default     = "full-cloud-devops-app"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

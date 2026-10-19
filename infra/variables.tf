variable "subscription_id" {
  type = string
}

variable "location" {
  type    = string
  default = "southafricanorth"
}

variable "project_name" {
  type    = string
  default = "minipoll"
}

variable "node_vm_size" {
  type    = string
  default = "Standard_D2s_v3" # 2 vCPUs, 8 GiB. Confirm it is offered in your region (see Stage 5)
}

variable "db_username" {
  type    = string
  default = "minipolladmin"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "alert_email" {
  type = string
}

variable "domain_name" {
  description = "Root domain, used in Stage 7"
  type        = string
  default     = "dmldev.site"
}

variable "ingress_ip" {
  description = "Public IP of the cluster ingress, filled in during Stage 7"
  type        = string
  default     = ""
}

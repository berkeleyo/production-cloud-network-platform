variable "name" {
  description = "Logical name for the reference Application Gateway."
  type        = string
  default     = "agw-synth-platform"

  validation {
    condition     = length(trimspace(var.name)) > 0
    error_message = "name must not be empty."
  }
}

variable "resource_group_name" {
  description = "Synthetic resource group for the ingress tier."
  type        = string

  validation {
    condition     = length(trimspace(var.resource_group_name)) > 0
    error_message = "resource_group_name must not be empty."
  }
}

variable "location" {
  description = "Azure region name used for design reference only."
  type        = string
  default     = "uksouth"

  validation {
    condition     = length(trimspace(var.location)) > 0
    error_message = "location must not be empty."
  }
}

variable "subnet_id" {
  description = "Subnet ID for the Application Gateway frontend."
  type        = string

  validation {
    condition     = length(trimspace(var.subnet_id)) > 0
    error_message = "subnet_id must not be empty."
  }
}

variable "backend_pool_addresses" {
  description = "Synthetic backend addresses for the application pool."
  type        = list(string)
  default     = ["10.20.0.10", "10.20.10.10"]

  validation {
    condition = alltrue([
      for address in var.backend_pool_addresses : can(cidrhost("${address}/32", 0))
    ])
    error_message = "backend_pool_addresses must be valid host addresses."
  }
}

variable "backend_port" {
  description = "Backend port used by the HTTPS health and routing settings."
  type        = number
  default     = 443

  validation {
    condition     = var.backend_port >= 1 && var.backend_port <= 65535
    error_message = "backend_port must be a valid TCP port between 1 and 65535."
  }
}

variable "backend_host" {
  description = "Synthetic backend host name for health probes and routing decisions."
  type        = string
  default     = "app.internal.synthetic"

  validation {
    condition     = length(trimspace(var.backend_host)) > 0
    error_message = "backend_host must not be empty."
  }
}

variable "health_path" {
  description = "Health probe path for the backend service."
  type        = string
  default     = "/health"

  validation {
    condition     = startswith(var.health_path, "/")
    error_message = "health_path must start with a leading slash."
  }
}

variable "frontend_port" {
  description = "Public frontend port for HTTPS traffic."
  type        = number
  default     = 443

  validation {
    condition     = var.frontend_port == 443
    error_message = "frontend_port must be 443 for the dedicated public HTTPS ingress design."
  }
}

variable "tls" {
  description = "Sensitive certificate object for the reference Application Gateway configuration."
  type = object({
    name     = string
    data     = string
    password = string
  })
  sensitive = true

  validation {
    condition     = length(trimspace(var.tls.name)) > 0 && length(trimspace(var.tls.data)) > 0 && length(trimspace(var.tls.password)) > 0 && can(base64decode(var.tls.data))
    error_message = "tls.name, tls.data, and tls.password must all be defined and tls.data must be a valid base64-encoded certificate payload."
  }
}

variable "tags" {
  description = "Synthetic tags used for reference-only infrastructure metadata."
  type        = map(string)
  default = {
    environment = "simulated"
    workload    = "cloud-network-platform"
    role        = "ingress"
  }
}

variable "waf_enabled" {
  description = "Whether the synthetic WAF policy is enabled for the application gateway."
  type        = bool
  default     = true

  validation {
    condition     = var.waf_enabled
    error_message = "The reference architecture requires WAF to remain enabled for the Application Gateway."
  }
}

variable "waf_policy_name" {
  description = "Logical name of the dedicated Azure WAF policy."
  type        = string
  default     = "waf-synth-platform"

  validation {
    condition     = length(trimspace(var.waf_policy_name)) > 0
    error_message = "waf_policy_name must not be empty."
  }
}

variable "waf_mode" {
  description = "Operational mode for the dedicated Azure WAF policy."
  type        = string
  default     = "Prevention"

  validation {
    condition     = contains(["Detection", "Prevention"], var.waf_mode)
    error_message = "waf_mode must be Detection or Prevention."
  }
}

variable "waf_max_request_body_size_in_kb" {
  description = "Maximum request body size inspected by the Azure WAF policy."
  type        = number
  default     = 128

  validation {
    condition     = var.waf_max_request_body_size_in_kb > 0 && var.waf_max_request_body_size_in_kb <= 1024
    error_message = "waf_max_request_body_size_in_kb must be greater than zero and within a conservative Azure WAF limit."
  }
}

variable "waf_file_upload_limit_in_mb" {
  description = "Maximum file upload size inspected by the Azure WAF policy."
  type        = number
  default     = 100

  validation {
    condition     = var.waf_file_upload_limit_in_mb > 0 && var.waf_file_upload_limit_in_mb <= 5000
    error_message = "waf_file_upload_limit_in_mb must be greater than zero and within a sensible Azure WAF limit."
  }
}

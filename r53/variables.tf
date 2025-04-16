variable "parent_domain" {
  description = "The parent domain name (e.g., example.com)"
  type        = string
  default     = "example.com"
}

variable "subdomain" {
  description = "The subdomain to create (e.g., demo.example.com)"
  type        = string
  default     = "demo.example.com"
} 
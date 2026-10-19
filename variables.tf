variable "aws_region" {
  description = "Región de AWS donde se crea todo"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefijo para nombrar los recursos"
  type        = string
  default     = "frappe-crm"
}

variable "instance_type" {
  description = <<-EOT
    Tipo de instancia. Debe ser x86_64 (la AMI es amd64), p. ej. t3.micro o t3.small.
    Revisa en la consola de EC2 cuáles aparecen como "Free tier eligible" en tu cuenta.
  EOT
  type        = string
  default     = "t3.small"
}

variable "disk_size_gb" {
  description = "Tamaño del disco raíz en GB (la capa gratuita cubre hasta 30 GB de EBS)"
  type        = number
  default     = 30
}

variable "ssh_cidr" {
  description = "Rango de IPs que pueden entrar por SSH. Lo ideal es tu IP pública con /32, p. ej. 181.50.10.20/32"
  type        = string
  default     = "0.0.0.0/0"
}

variable "crm_cidr" {
  description = "Rango de IPs que pueden abrir el CRM en el puerto 8000"
  type        = string
  default     = "0.0.0.0/0"
}

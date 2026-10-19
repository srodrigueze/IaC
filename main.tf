terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------------
# AMI: Ubuntu 24.04 LTS oficial de Canonical (x86_64)
# ---------------------------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------------------------------------------------------------------------
# Red: usamos la VPC por defecto de la cuenta (lo más simple para empezar)
# ---------------------------------------------------------------------------
data "aws_vpc" "default" {
  default = true
}

# ---------------------------------------------------------------------------
# Llave SSH generada por Terraform
# (la privada se guarda en un .pem local y también queda en el state:
#  está bien para aprender, no para producción)
# ---------------------------------------------------------------------------
resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "this" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.ssh.private_key_openssh
  filename        = "${path.module}/${var.project_name}-key.pem"
  file_permission = "0600"
}

# ---------------------------------------------------------------------------
# Security Group: SSH (22) y Frappe CRM (8000)
# ---------------------------------------------------------------------------
resource "aws_security_group" "crm" {
  name        = "${var.project_name}-sg"
  description = "Acceso SSH y web para Frappe CRM"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  ingress {
    description = "Frappe CRM"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = [var.crm_cidr]
  }

  egress {
    description = "Salida a internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg"
    Project = var.project_name
  }
}

# ---------------------------------------------------------------------------
# La VM: al arrancar ejecuta user_data.sh (Docker + Frappe CRM)
# ---------------------------------------------------------------------------
resource "aws_instance" "crm" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.this.key_name
  vpc_security_group_ids = [aws_security_group.crm.id]

  user_data                   = file("${path.module}/user_data.sh")
  user_data_replace_on_change = true

  root_block_device {
    volume_size = var.disk_size_gb
    volume_type = "gp3"
  }

  tags = {
    Name    = "${var.project_name}-vm"
    Project = var.project_name
  }
}

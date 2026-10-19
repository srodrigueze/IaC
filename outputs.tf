output "public_ip" {
  description = "IP pública de la VM"
  value       = aws_instance.crm.public_ip
}

output "crm_url" {
  description = "URL del CRM (tarda ~15-25 min en estar listo tras el apply)"
  value       = "http://${aws_instance.crm.public_ip}:8000/crm"
}

output "ssh_command" {
  description = "Comando para conectarte a la VM"
  value       = "ssh -i ${local_sensitive_file.private_key.filename} ubuntu@${aws_instance.crm.public_ip}"
}

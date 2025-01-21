output "instance_public_ips" {
  description = "Adresses IP publiques des instances EC2"
  value       = [for instance in aws_instance.ubuntu_server : instance.public_ip]
}

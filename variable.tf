variable "aws_region" {
  description = "Région AWS pour le déploiement"
  default     = "eu-west-3" # Exemple : Paris
}

variable "ami_id" {
  description = "ID de l'AMI à utiliser pour les instances EC2"
  default     = "ami-06e02ae7bdac6b938" # Ubuntu 20.04
}

variable "instance_type" {
  description = "Type d'instance EC2"
  default     = "t2.micro"
}

variable "bucket_name" {
  description = "Nom du bucket S3"
  default     = "bucket-terraform-unique-123456" # Assurez-vous que ce nom est unique
}

variable "key_pair_name" {
  description = "Nom de la paire de clés SSH"
  default     = "my-key"
}

variable "public_key_path" {
  description = "Chemin vers le fichier de clé publique SSH"
  default     = "~/.ssh/my-key.pub"
}

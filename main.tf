# Création du VPC
resource "aws_vpc" "main_vpc" {
  cidr_block = "192.168.0.0/16"
  tags = { Name = "VPC" }
}

# Passerelle Internet
resource "aws_internet_gateway" "main_gw" {
  vpc_id = aws_vpc.main_vpc.id
  tags = { Name = "IGW" }
}

# Sous-réseau public
resource "aws_subnet" "main_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "192.168.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-west-3a"
  tags = { Name = "Subnet" }
}

# Table de routage
resource "aws_route_table" "main_rt" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_gw.id
  }
  tags = { Name = "RouteTable" }
}

# Association de la table de routage
resource "aws_route_table_association" "main_rta" {
  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.main_rt.id
}

# Groupe de sécurité
resource "aws_security_group" "main_sg" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "SecurityGroup" }
}

# Bucket S3
resource "aws_s3_bucket" "private_bucket" {
  bucket = var.bucket_name

  tags = { Name = "BucketTerraform" }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [bucket]
  }
}

resource "aws_s3_bucket_versioning" "private_bucket_versioning" {
  bucket = aws_s3_bucket.private_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Paire de clés SSH
resource "aws_key_pair" "my_key" {
  key_name   = var.key_pair_name
  public_key = file(var.public_key_path)

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [key_name]
  }
}

# Instances EC2
resource "aws_instance" "ubuntu_server" {
  count                  = 3
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.main_subnet.id
  vpc_security_group_ids = [aws_security_group.main_sg.id]
  associate_public_ip_address = true
  key_name               = aws_key_pair.my_key.key_name

  user_data = <<-EOT
                #!/bin/bash
                echo "$(cat ${var.public_key_path})" >> /home/ubuntu/.ssh/authorized_keys
                chmod 600 /home/ubuntu/.ssh/authorized_keys
                chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys
             EOT

  private_ip = format("192.168.1.%d", 10 + count.index)

  tags = {
    Name = "Node-${count.index + 1}"
  }
}

# README.md

## Projet : Automatisation de l'infrastructure avec Terraform et Ansible

### **Objectif du projet**
L'objectif de ce projet est de déployer une infrastructure cloud sur AWS en utilisant Terraform pour provisionner les ressources nécessaires, et Ansible pour configurer les instances. Nous avons également versionné le travail en le poussant sur GitHub.

---

### **Prérequis**
1. **Terraform** : Installé sur votre machine.
2. **Ansible** : Installé sur votre machine.
3. **AWS CLI** : Configuré avec un utilisateur ayant les permissions nécessaires.
4. **Clé SSH** : Générée pour accéder aux instances EC2.
5. **Compte GitHub** : Pour versionner le code.

---

### **Étapes du projet**

#### **1. Fichiers Terraform**

##### **provider.tf**
```hcl
provider "aws" {
  region = var.aws_region
}
```

##### **main.tf**
```hcl
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

```

##### **outputs.tf**
```hcl
output "instance_public_ips" {
  description = "Adresses IP publiques des instances EC2"
  value       = [for instance in aws_instance.ubuntu_server : instance.public_ip]
}
```

##### **variables.tf**
```hcl
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
```

#### **2. Initialisation et déploiement avec Terraform**
- **Initialiser Terraform** :
  ```bash
  terraform init
  ```

- **Vérifier le plan de déploiement** :
  ```bash
  terraform plan
  ```

- **Appliquer la configuration** :
  ```bash
  terraform apply
  ```

- **Récupérer les IP publiques des instances** :
  ```bash
  terraform output instance_public_ips
  ```

#### **3. Création d'un inventaire Ansible**
Un fichier `inventory.ini` a été créé pour lister les adresses IP des instances EC2 :
```ini
[nodes]
13.38.103.191 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/my-key
13.36.171.27 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/my-key
35.180.121.64 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/my-key

```
#### **4. installer docker avec le fchier script**
Le fichier `install_docker.sh` a été écrit pour installer Docker  :
``` sh
#!/bin/bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y ca-certificates curl gnupg
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable docker
sudo systemctl start docker
sudo chmod 777 /var/run/docker.sock
sudo usermod -aG docker $USER
docker --version && echo "Docker a été installé avec succès et est prêt à l'emploi."


```
#### **4. Création d'un playbook Ansible**
Le fichier `docker_playbook.yml` a été écrit pour installer Docker sur toutes les instances EC2 :
```yaml
---
- name: Install Docker on EC2 instances
  hosts: nodes
  become: true
  tasks:
    - name: Copy Docker installation script
      copy:
        src: ./install_docker.sh
        dest: /tmp/install_docker.sh
        mode: '0755'

    - name: Run Docker installation script
      command: /tmp/install_docker.sh

```

#### **5. Exécution du playbook Ansible**
Pour déployer Docker sur toutes les instances :
```bash
ansible-playbook -i inventory.ini docker_playbook.yml
```

#### **6. Pousser le projet sur GitHub**
1. Initialisez le dépôt Git :
   ```bash
   git init
   ```
2. Ajoutez les fichiers :
   ```bash
   git add .
   ```
3. Commitez les modifications :
   ```bash
   git commit -m "Ajout des fichiers Terraform et Ansible"
   ```
4. Ajoutez le dépôt distant :
   ```bash
   git remote add origin https://github.com/marwa9999/TP-terraform1
  


terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "Analytics-DevOps"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "DevOps-Team"
    }
  }
}

# VPC and Networking
module "networking" {
  source = "./modules/networking"
  
  environment    = var.environment
  vpc_cidr       = var.vpc_cidr
  public_subnets = var.public_subnets
}

# IAM Roles and Policies
module "iam" {
  source = "./modules/iam"
  
  environment = var.environment
}

# EC2 Instances
module "ec2_jenkins" {
  source = "./modules/ec2"
  
  name               = "jenkins-master"
  instance_type      = var.jenkins_instance_type
  subnet_id          = module.networking.public_subnet_ids[0]
  security_group_ids = [module.networking.jenkins_sg_id]
  key_name           = var.key_name
  iam_instance_profile = module.iam.jenkins_instance_profile
  
  user_data = base64encode(templatefile("${path.module}/user_data/jenkins.sh", {
    environment = var.environment
  }))
  
  tags = {
    Role = "Jenkins-Master"
    Type = "CI-CD"
  }
}

module "ec2_k8s_workers" {
  source = "./modules/ec2"
  count  = 3
  
  name               = "k8s-worker-${count.index + 1}"
  instance_type      = var.worker_instance_type
  subnet_id          = module.networking.public_subnet_ids[count.index % length(module.networking.public_subnet_ids)]
  security_group_ids = [module.networking.k8s_sg_id]
  key_name           = var.key_name
  iam_instance_profile = module.iam.k8s_instance_profile
  
  user_data = base64encode(templatefile("${path.module}/user_data/k8s_worker.sh", {
    environment = var.environment
    worker_id   = count.index + 1
  }))
  
  tags = {
    Role = "Kubernetes-Worker"
    Type = "Container-Host"
  }
}

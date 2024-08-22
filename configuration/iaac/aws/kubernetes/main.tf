terraform {
  backend "s3" {
    bucket = "aws-backend-state-sayanti-234" # Will be overridden from build
    key    = "path/to/my/key" # Will be overridden from build
    region = "us-east-1"
  }
}

resource "aws_default_vpc" "default" {
}

data "aws_subnet" "subnet1" {
  vpc_id = aws_default_vpc.default.id

  filter {
    name   = "availability-zone"
    values = ["us-east-1a"]  # First Availability Zone
  }
}

data "aws_subnet" "subnet2" {
  vpc_id = aws_default_vpc.default.id

  filter {
    name   = "availability-zone"
    values = ["us-east-1b"]  # Second Availability Zone
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  version                = "~> 2.12"
}

module "in28minutes-cluster" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "17.10.0"
  cluster_name    = "in28minutes-cluster"
  cluster_version = "1.25"
  subnets         = [data.aws_subnet.subnet1.id, data.aws_subnet.subnet2.id]  # Subnets in different AZs
  vpc_id          = aws_default_vpc.default.id

  worker_groups = [
    {
      instance_type = "t2.micro"
      asg_max_size  = 3
    }
  ]
}

data "aws_eks_cluster" "cluster" {
  name = module.in28minutes-cluster.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.in28minutes-cluster.cluster_id
}

resource "kubernetes_cluster_role_binding" "example" {
  metadata {
    name = "fabric8-rbac"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "default"
  }
}

# Create a secret. After version 1.23 there is no default secret
resource "kubernetes_secret" "example" {
  metadata {
    annotations = {
      "kubernetes.io/service-account.name" = "default"
    }

    generate_name = "terraform-default-"
  }

  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
}

provider "aws" {
  region  = "us-east-1"
}
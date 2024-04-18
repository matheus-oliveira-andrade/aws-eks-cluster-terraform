module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.7.1"

  name = "${var.cluster_name}_vpc"
  cidr = "10.0.0.0/16"

  azs = ["${var.region}a", "${var.region}b"]

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" : "1"
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  tags = {
    env                                         = "dev"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.16.0"

  cluster_name    = var.cluster_name
  cluster_version = var.eks_version

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_irsa = true

  eks_managed_node_group_defaults = {
  }

  eks_managed_node_groups = {
    instances = {
      min_size     = 1
      max_size     = 2
      desired_size = 1

      instance_types = var.instance_types
      capacity_type  = var.instance_capacity_type
    }
  }

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  tags = {
    env = "dev"
  }
}

### BEGIN AWS LOAD BALANCER CONTROLLER

## PERMISSIONS TO ALB CONTROLLER POLICY
data "local_file" "alb_controller_permissions" {
  filename = "alb_controller_permissions.json"
}

## POLICY TO ALB INGRESS CONTROLLER
resource "aws_iam_policy" "alb_ingress_controller_policy" {
  name        = "ALBIngressControllerIAMPolicy"
  description = "Policy which will be used by role for service - for creating alb from within cluster by issuing declarative kube commands"
  policy      = data.local_file.alb_controller_permissions.content
}

# ROLE TO ALB INGRESS CONTROLLER
resource "aws_iam_role" "alb-ingress-controller-role" {
  name = "alb-ingress-controller"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Federated": "${module.eks.oidc_provider_arn}"     
},
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${replace(module.eks.oidc_provider, "https://", "")}:sub": "system:serviceaccount:kube-system:alb-ingress-controller",
          "${replace(module.eks.oidc_provider, "https://", "")}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
POLICY

  depends_on = [module.eks.oidc_provider]

  tags = {
    "ServiceAccountName"      = "alb-ingress-controller"
    "ServiceAccountNameSpace" = "kube-system"
  }
}

# Attach policies to IAM role
resource "aws_iam_role_policy_attachment" "alb-ingress-controller-role-ALBIngressControllerIAMPolicy" {
  policy_arn = aws_iam_policy.alb_ingress_controller_policy.arn
  role       = aws_iam_role.alb-ingress-controller-role.name
  depends_on = [aws_iam_role.alb-ingress-controller-role]
}

resource "aws_iam_role_policy_attachment" "alb-ingress-controller-role-AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.alb-ingress-controller-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  depends_on = [aws_iam_role.alb-ingress-controller-role]
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.cluster_name
    ]
  }
}

resource "kubernetes_service_account" "alb-ingress-controller-sa" {
  metadata {
    name      = "alb-ingress-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb-ingress-controller-role.arn
    }
    labels = {
      "app.kubernetes.io/name" = "alb-ingress-controller"
    }
  }
}

resource "kubernetes_cluster_role" "alb_ingress_controller" {
  metadata {
    labels = {
      "app.kubernetes.io/name" = "alb-ingress-controller"
    }
    name = "alb-ingress-controller"
  }

  rule {
    api_groups = [""]
    resources = [
      "configmaps",
      "endpoints",
      "events",
      "ingresses",
      "ingresses/status",
      "services",
      "pods/status",
    ]
    verbs = ["create", "get", "list", "update", "watch", "patch"]
  }

  rule {
    api_groups = [""]
    resources = [
      "nodes",
      "pods",
      "secrets",
      "services",
      "namespaces",
    ]
    verbs = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "alb_ingress_controller" {
  metadata {
    labels = {
      "app.kubernetes.io/name" = "alb-ingress-controller"
    }
    name = "alb-ingress-controller"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.alb_ingress_controller.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "alb-ingress-controller"
    namespace = "kube-system"
  }
}


provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        module.eks.cluster_name
      ]
    }
  }
}


resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "alb-ingress-controller"
  }
}

### END AWS LOAD BALANCER CONTROLLER
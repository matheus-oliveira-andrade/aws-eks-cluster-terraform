data "local_file" "permissions" {
  filename = "./aws-load-balancer/permissions.json"
}

resource "aws_iam_policy" "lb_controller_policy" {
  name        = "ALBIngressControllerIAMPolicy"
  description = "Policy which will be used by role for service - for creating alb from within cluster by issuing declarative kube commands"
  policy      = data.local_file.permissions.content
}

resource "aws_iam_role" "lb-ingress-controller-role" {
  name = "alb-ingress-controller"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Federated": "${var.oidc_provider_arn}"     
},
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${replace(var.oidc_provider, "https://", "")}:sub": "system:serviceaccount:kube-system:alb-ingress-controller",
          "${replace(var.oidc_provider, "https://", "")}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
POLICY

  depends_on = [var.oidc_provider]

  tags = {
    "ServiceAccountName"      = "alb-ingress-controller"
    "ServiceAccountNameSpace" = "kube-system"
  }
}

resource "aws_iam_role_policy_attachment" "alb-ingress-controller-role-ALBIngressControllerIAMPolicy" {
  policy_arn = aws_iam_policy.lb_controller_policy.arn
  role       = aws_iam_role.lb-ingress-controller-role.name
  depends_on = [aws_iam_role.lb-ingress-controller-role]
}

resource "aws_iam_role_policy_attachment" "alb-ingress-controller-role-AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.lb-ingress-controller-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  depends_on = [aws_iam_role.lb-ingress-controller-role]
}

resource "kubernetes_service_account" "lb-controller-sa" {
  metadata {
    name      = var.service_account_name
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.lb-ingress-controller-role.arn
    }
    labels = {
      "app.kubernetes.io/name" = var.service_account_name
    }
  }
}

resource "kubernetes_cluster_role" "allow_aws_lb_controller" {
  metadata {
    labels = {
      "app.kubernetes.io/name" = "allow_aws_lb_controller"
    }
    name = "allow_aws_lb_controller"
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

resource "kubernetes_cluster_role_binding" "lb_controller_rb" {
  metadata {
    labels = {
      "app.kubernetes.io/name" = "lb_controller_rb"
    }
    name = "lb_controller_rb"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.allow_aws_lb_controller.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = var.service_account_name
    namespace = "kube-system"
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = var.service_account_name
  }
}
# 允许 Pods 通过 CSI（容器存储接口）访问 Secrets, 基础的 CSI 驱动，用于与 Kubernetes 进行集成
resource "helm_release" "secrets_csi_driver" {
  name = "secrets-store-csi-driver"

  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  namespace  = "kube-system"
  version    = "1.4.3"

  # MUST be set if you use ENV variables
  # syncSecret.enabled = true 的同步操作只在最初挂载 Secret 时发生，
  # 之后即使 AWS Secrets Manager 中的值变化，Kubernetes 中的 Secret 也不会自动更新。
  set {
    name  = "syncSecret.enabled"
    value = true
  }

  depends_on = [helm_release.efs_csi_driver]
}

# 此插件使得 CSI 驱动能够与 AWS Secrets Manager 集成，从 AWS 中获取秘密并提供给 Pod。
resource "helm_release" "secrets_csi_driver_aws_provider" {
  name = "secrets-store-csi-driver-provider-aws"

  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  namespace  = "kube-system"
  version    = "0.3.9"

  depends_on = [helm_release.secrets_csi_driver]
}

# 配置角色的trust policy，定义谁能够使用这个角色
data "aws_iam_policy_document" "myapp_secrets" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      # 只允许namespace 12-example下的service account myapp来获取对应AWS的role
      values   = ["system:serviceaccount:12-example:myapp"] 
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}

# 创建角色
resource "aws_iam_role" "myapp_secrets" {
  name               = "${aws_eks_cluster.eks.name}-myapp-secrets"
  assume_role_policy = data.aws_iam_policy_document.myapp_secrets.json
}

# 创建角色拥有的policy权限
resource "aws_iam_policy" "myapp_secrets" {
  name = "${aws_eks_cluster.eks.name}-myapp-secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*" # "arn:*:secretsmanager:*:*:secret:my-secret-kkargS"
      }
    ]
  })
}

# 关联角色与policy
resource "aws_iam_role_policy_attachment" "myapp_secrets" {
  policy_arn = aws_iam_policy.myapp_secrets.arn
  role       = aws_iam_role.myapp_secrets.name
}

# 将角色的arn输出
output "myapp_secrets_role_arn" {
  value = aws_iam_role.myapp_secrets.arn
}
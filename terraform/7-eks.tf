# 创建EKS使用的IAM role
resource "aws_iam_role" "eks" {
  name = "${local.env}-${local.eks_name}-eks-cluster"

  assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "eks.amazonaws.com"
            }
        }
    ]
}
POLICY
}

# 给Role分配IAM Policy
resource "aws_iam_role_policy_attachment" "eks" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role = aws_iam_role.eks.name
}

# 创建EKS cluster
resource "aws_eks_cluster" "eks" {
  name = "${local.env}-${local.eks_name}"
  version = local.eks_version
  role_arn = aws_iam_role.eks.arn

  vpc_config {
    # https://docs.aws.amazon.com/eks/latest/userguide/cluster-endpoint.html
    endpoint_private_access = false
    endpoint_public_access = true

    subnet_ids = [
        aws_subnet.private_zone1.id,
        aws_subnet.private_zone2.id,
    ]
  }

  access_config {
    # authentication_mode = "API" 配置允许 EKS 使用 AWS IAM 来处理 Kubernetes 集群的身份验证请求，
    # 控制哪些用户和角色可以访问 Kubernetes API。它通过 IAM 来验证访问请求，
    # 但访问权限细化控制仍然由 Kubernetes 内部的 RBAC 进行管理。
    authentication_mode = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  # 等EKS的role与poilcy关联完毕后，才开始创建此EKS cluster
  depends_on = [ aws_iam_role_policy_attachment.eks ]
}
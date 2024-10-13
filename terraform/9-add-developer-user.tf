# 创建IAM user
resource "aws_iam_user" "developer" {
  name = "developer"
}

# 创建最小的EKS权限
resource "aws_iam_policy" "developer_eks" {
  name = "AmazonEKSDeveloperPolicy"

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "eks:DescribeCluster",
                "eks:ListClusters"
            ],
            "Resource": "*"
        }
    ]
}
POLICY
}

# 将IAM user与policy关联，（赋予IAM user相应的plicy权限）
resource "aws_iam_user_policy_attachment" "developer_eks" {
  user = aws_iam_user.developer.name
  policy_arn = aws_iam_policy.developer_eks.arn
}

# 最重要的一步，通过EKS API，将IAM user与K8S group关联起来
resource "aws_eks_access_entry" "develop" {
  cluster_name = aws_eks_cluster.eks.name
  principal_arn = aws_iam_user.developer.arn
  kubernetes_groups = ["my-viewer"]
}
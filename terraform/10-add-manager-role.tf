# 获取当前aws账户的信息
data "aws_caller_identity" "current" {}

# 管理员权限的IAM role，配置它可以被上面的current使用，即当前aws账户
resource "aws_iam_role" "eks_admin" {
  name = "${local.env}-${local.eks_name}-eks-admin"

  assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Principal": {
                "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
            }
        }
    ]
}
POLICY
}

# eks管理员权限的policy
resource "aws_iam_policy" "eks_admin" {
  name = "AmazonEKSAdminPolicy"

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "eks:*"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "iam:PassedToService": "eks.amazonaws.com"
                }
            }
        }
    ]
}
POLICY
}

# 将eks admin 角色附上eks admin的policy
resource "aws_iam_role_policy_attachment" "eks_admin" {
  role = aws_iam_role.eks_admin.name
  policy_arn = aws_iam_policy.eks_admin.arn
}

# 创建一个IAM user，让它来assume上面创建的eks admin role
resource "aws_iam_user" "manager" {
  name = "manager"
}

# 为了上面的manager user创建一个policy，可以assume eks admin role
resource "aws_iam_policy" "eks_assume_admin" {
  name = "AmazonEKSAssumeAdminPolicy"

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "sts:AssumeRole"
            ],
            "Resource": "${aws_iam_role.eks_admin.arn}"
        }
    ]
}
POLICY
}

# 给manager user附上可以assume eks admin role的policy
resource "aws_iam_user_policy_attachment" "manager" {
  user = aws_iam_user.manager.name
  policy_arn = aws_iam_policy.eks_assume_admin.arn
}

# 将iam role与k8s的group 'my-admin'关联
resource "aws_eks_access_entry" "manager" {
  cluster_name = aws_eks_cluster.eks.name
  principal_arn = aws_iam_role.eks_admin.arn
  kubernetes_groups = ["my-admin"]
}
# 创建EBS CSI driver role的trust policy
data "aws_iam_policy_document" "ebs_csi_driver" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

# 使用上面的trust policy创建EBS CSI driver的role
resource "aws_iam_role" "ebs_csi_driver" {
  name               = "${aws_eks_cluster.eks.name}-ebs-csi-driver"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_driver.json
}

# 将上面创建的ebs_csi_driver role附上AWS自带的policy AmazonEBSCSIDriverPolicy
resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver.name
}

# 加密EBS Optional: only if you want to encrypt the EBS drives
resource "aws_iam_policy" "ebs_csi_driver_encryption" {
  name = "${aws_eks_cluster.eks.name}-ebs-csi-driver-encryption"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:CreateGrant"
        ]
        Resource = "*"
      }
    ]
  })
}

#加密EBS的policy，附在ebs_csi_driver role上 
# Optional: only if you want to encrypt the EBS drives
resource "aws_iam_role_policy_attachment" "ebs_csi_driver_encryption" {
  policy_arn = aws_iam_policy.ebs_csi_driver_encryption.arn
  role       = aws_iam_role.ebs_csi_driver.name
}

# 把aws iam role与k8s cluster的servcie account 关联
resource "aws_eks_pod_identity_association" "ebs_csi_driver" {
  cluster_name    = aws_eks_cluster.eks.name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi_driver.arn
}

# 通过eks addon的方式安装ebs csi driver
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = aws_eks_cluster.eks.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.30.0-eksbuild.1"
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn
}
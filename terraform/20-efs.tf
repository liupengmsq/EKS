# 创建EFS文件系统
resource "aws_efs_file_system" "eks" {
  creation_token = "eks"

  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = true

  # lifecycle_policy {
  #   transition_to_ia = "AFTER_30_DAYS"
  # }
}

# 将两个private AZ附上EFS的mount target
resource "aws_efs_mount_target" "zone_a" {
  file_system_id  = aws_efs_file_system.eks.id
  subnet_id       = aws_subnet.private_zone1.id
  security_groups = [aws_eks_cluster.eks.vpc_config[0].cluster_security_group_id]
}

resource "aws_efs_mount_target" "zone_b" {
  file_system_id  = aws_efs_file_system.eks.id
  subnet_id       = aws_subnet.private_zone2.id
  security_groups = [aws_eks_cluster.eks.vpc_config[0].cluster_security_group_id]
}

# 配置EFS CSI dirver所需要的IAM role的trust policy
# 配置了允许 Kubernetes 中的kube-system 命名空间中的 efs-csi-controller-sa 服务账户
# 假设一个 IAM 角色，这个角色是 EFS CSI 驱动与 AWS 服务交互所需的权限。
data "aws_iam_policy_document" "efs_csi_driver" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      # 这里引用了 EKS 集群的 OIDC 提供商的 URL，并通过 replace 函数
      # 去掉了 https:// 前缀，从而构建 OIDC 的 "subject" 字符串，指代 Kubernetes 的服务账户。
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"

      # 这里定义了允许的 OIDC 主题值。它指定了只有 kube-system 命名空间
      # 中的 efs-csi-controller-sa 服务账户可以假设该角色
      values   = ["system:serviceaccount:kube-system:efs-csi-controller-sa"]
    }

    # 定义了可以假设该角色的主体实体
    principals {
    # 这里指定了与 EKS 集群关联的 OIDC 提供商的 ARN。
      identifiers = [aws_iam_openid_connect_provider.eks.arn]

      # 这一行将主体类型设置为 Federated，表示该角色可以由联合身份（如 Kubernetes 提供的 OIDC 身份）假设。
      type        = "Federated"
    }
  }
}

# 角色附上trust policy
resource "aws_iam_role" "efs_csi_driver" {
  name               = "${aws_eks_cluster.eks.name}-efs-csi-driver"
  assume_role_policy = data.aws_iam_policy_document.efs_csi_driver.json
}

# 角色附上AWS自带的IAM policy，允许操作EFS
resource "aws_iam_role_policy_attachment" "efs_csi_driver" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
  role       = aws_iam_role.efs_csi_driver.name
}

# 使用helm向K8S中安装EFS CSI driver
resource "helm_release" "efs_csi_driver" {
  name = "aws-efs-csi-driver"

  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver/"
  chart      = "aws-efs-csi-driver"
  namespace  = "kube-system"
  version    = "3.0.5"

  # 配置driver在K8S中的service account
  set {
    name  = "controller.serviceAccount.name"
    value = "efs-csi-controller-sa"
  }
  # 配置driver使用的IAM role，就是我们上面配置的role
  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.efs_csi_driver.arn
  }

  depends_on = [
    aws_efs_mount_target.zone_a,
    aws_efs_mount_target.zone_b
  ]
}

# 如下是使用helm来在K8S中创建EFS的storageclass
# Optional since we already init helm provider (just to make it self contained)
data "aws_eks_cluster" "eks_v2" {
  name = aws_eks_cluster.eks.name
}

# Optional since we already init helm provider (just to make it self contained)
data "aws_eks_cluster_auth" "eks_v2" {
  name = aws_eks_cluster.eks.name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks_v2.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks_v2.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks_v2.token
}

resource "kubernetes_storage_class_v1" "efs" {
  metadata {
    name = "efs"
  }

  storage_provisioner = "efs.csi.aws.com"

  parameters = {
    provisioningMode = "efs-ap" # 指定 EFS 存储的提供模式，这里为 EFS 的接入点 (Access Point) 模式。
    fileSystemId     = aws_efs_file_system.eks.id
    directoryPerms   = "700" # 指定文件系统目录的权限为 700，即所有者拥有读、写和执行权限，其他用户没有任何权限。
  }

  mount_options = ["iam"] # 指定挂载时使用 IAM 角色来控制权限

  depends_on = [helm_release.efs_csi_driver]
}
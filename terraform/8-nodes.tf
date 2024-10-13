# 创建EKS node group(worker node)使用的IAM role
resource "aws_iam_role" "nodes" {
  name = "${local.env}-${local.eks_name}-eks-nodes"
  
  assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            }
        }
    ]
}
POLICY
}

# 让EKS中的worker node有权限连接EKS master node，
# 并且最后一个Action：eks-auth:AssumeRoleForPodIdentity，
# 是为了让worker node中的Pod有权限访问外部aws的其他servcie，使用的一个叫做Pod Identity的技术。
resource "aws_iam_role_policy_attachment" "amazon_eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role = aws_iam_role.nodes.name
}

# 让Amazon VPC CNI Plugin (amazon-vpc-cni-k8s)插件可以有权限更改worker node中的网络配置
resource "aws_iam_role_policy_attachment" "amazon_eks_cni_plicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role = aws_iam_role.nodes.name
}

# 允许从worker node中读取ECR image
resource "aws_iam_role_policy_attachment" "amazon_ec2_container_registry-read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role = aws_iam_role.nodes.name
}

# 定义worker node的node group，其实就是一个autoscaling group
resource "aws_eks_node_group" "general" {
  cluster_name = aws_eks_cluster.eks.name
  version = local.eks_version
  node_group_name = "general"
  node_role_arn = aws_iam_role.nodes.arn

  subnet_ids = [
    aws_subnet.private_zone1.id,
    aws_subnet.private_zone2.id,
  ]

  # 配置使用的instance type
  capacity_type = "ON_DEMAND"
  instance_types = ["t2.medium"]

  # 配置scaling的大小 
  scaling_config {
    desired_size = 3
    max_size = 4
    min_size = 1
  }

  # node group upgrade的时候最多只有一个instance会被更新
  update_config {
    max_unavailable = 1
  }

  # node在k8s中的label，可以用来做节点亲和性
  labels = {
    role = "general"
  }

  # 等待关联的iam role已经付上了policy
  depends_on = [ 
    aws_iam_role_policy_attachment.amazon_eks_worker_node_policy,
    aws_iam_role_policy_attachment.amazon_eks_cni_plicy,
    aws_iam_role_policy_attachment.amazon_ec2_container_registry-read_only,
   ]

  lifecycle {
    # 应用terraform的时候，忽略desired_size的对比，因为它是自动变化的
    ignore_changes = [ scaling_config[0].desired_size ]
  }
}
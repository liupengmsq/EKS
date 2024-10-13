resource "helm_release" "metrics_server" {
  name = "metrics-server"

  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart = "metrics-server"
  namespace = "kube-system"
  version = "3.12.1"

  # 配置此chart的定制的values, 位于当前模组的values目录下
  values = [ file("${path.module}/values/metrics-server.yaml") ]

  # 等eks的node group创建完成后在安装metrics server
  depends_on = [ aws_eks_node_group.general ]
}
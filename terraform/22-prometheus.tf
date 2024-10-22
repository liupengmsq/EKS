# CloudWatch Log Group 被创建以存储 Prometheus 的日志信息，日志保留 14 天。
resource "aws_cloudwatch_log_group" "prometheus_demo" {
  name              = "/aws/prometheus/demo"
  retention_in_days = 14
}

# Amazon Managed Prometheus Workspace 被创建，并配置了日志记录，将日志写入到指定的 CloudWatch Log Group。
resource "aws_prometheus_workspace" "demo" {
  alias = "demo"

  logging_configuration {
    log_group_arn = "${aws_cloudwatch_log_group.prometheus_demo.arn}:*"
  }

  depends_on = [aws_cloudwatch_log_group.prometheus_demo]
}

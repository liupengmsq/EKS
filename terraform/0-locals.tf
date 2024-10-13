locals {
    env = "staging"
    region = "us-east-2"

    # EKS需要配置至少两个AZ
    zone1 = "us-east-2a"
    zone2 = "us-east-2b"

    # eks cluster的名字
    eks_name = "demo"
    # eks的版本
    eks_version = "1.29"
}
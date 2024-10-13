provider "aws" {
    # 引用local的变量region
    region = local.region
}

terraform {
    required_version = ">= 1.0"

    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 5.49"
        }

        helm = {
            source = "hashicorp/helm"
            version = "2.15.0"
        }
    }
}
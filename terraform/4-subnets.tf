# 在zone1中配置私有子网1
resource "aws_subnet" "private_zone1" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.0.0/19"
    availability_zone = local.zone1

    tags = {
        "Name" = "${local.env}-private-${local.zone1}"

        # 告诉AWS load balancer controller，这个子网是private的，
        # 可以被internal load balancer所使用
        "kubernetes.io/role/internal-elb" = "1" 
    }
}

# 在zong2中配置私有子网2
resource "aws_subnet" "private_zone2" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.32.0/19"
    availability_zone = local.zone2

    tags = {
        "Name" = "${local.env}-private-${local.zone2}"

        # 告诉AWS load balancer controller，这个子网是private的，
        # 可以被internal load balancer所使用
        "kubernetes.io/role/internal-elb" = "1" 
    }
}

# 在zong1中配置公有子网1
resource "aws_subnet" "public_zone1" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.64.0/19"
    availability_zone = local.zone1
    # 配置ec2自动被分配public ip
    map_public_ip_on_launch = true

    tags = {
        "Name" = "${local.env}-public-${local.zone1}"

        # 告诉AWS load balancer controller，这个子网是public的，
        # 可以被public load balancer所使用
        "kubernetes.io/role/elb" = "1" 
    }
}

# 在zong1中配置公有子网2
resource "aws_subnet" "public_zone2" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.96.0/19"
    availability_zone = local.zone2
    # 配置ec2自动被分配public ip
    map_public_ip_on_launch = true

    tags = {
        "Name" = "${local.env}-public-${local.zone2}"

        # 告诉AWS load balancer controller，这个子网是public的，
        # 可以被public load balancer所使用
        "kubernetes.io/role/elb" = "1" 
    }
}
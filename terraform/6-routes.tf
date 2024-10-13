resource "aws_route_table" "private" {
    vpc_id = aws_vpc.main.id

    route {
        # 配置当subent中请求的目的IP地址不匹配子网所在的IP范围时，将转发给nat gateway
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.nat.id
    }

    tags = {
        Name = "${local.env}-private"
    }
}

resource "aws_route_table" "public" {
    vpc_id = aws_vpc.main.id

    route {
        # 配置当subent中请求的目的IP地址不匹配子网所在的IP范围时，将转发给internet gateway
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }

    tags = {
        Name = "${local.env}-public"
    }
}

# 给private-zone1子网附上路由表private
resource "aws_route_table_association" "private_zone1" {
    subnet_id = aws_subnet.private_zone1.id
    route_table_id = aws_route_table.private.id
}

# 给private-zone2子网附上路由表private
resource "aws_route_table_association" "private_zone2" {
    subnet_id = aws_subnet.private_zone2.id
    route_table_id = aws_route_table.private.id
}

# 给public-zone1子网附上路由表public
resource "aws_route_table_association" "public_zone1" {
    subnet_id = aws_subnet.public_zone1.id
    route_table_id = aws_route_table.public.id
}

# 给public-zone2子网附上路由表public
resource "aws_route_table_association" "public_zone2" {
    subnet_id = aws_subnet.public_zone2.id
    route_table_id = aws_route_table.public.id
}
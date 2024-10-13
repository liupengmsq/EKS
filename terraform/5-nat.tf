# 给nat gateway准备的静态IP地址
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${local.env}-nat"
  }
}

resource "aws_nat_gateway" "nat" {
    # 引用上面创建的静态ip地址
    allocation_id = aws_eip.nat.id

    # 将nat放到一个public subnet中，以便在private subnet的service可以使用它访问外网，因为这个nat是在public subnet中的
    subnet_id = aws_subnet.public_zone1.id

    tags = {
      Name = "${local.env}-nat"
    }

    # 等待internet gateway创建后再创建这个nat，保证创建nat之前外网是通的
    depends_on = [ aws_internet_gateway.igw ]
  
}
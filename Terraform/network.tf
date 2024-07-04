resource "aws_vpc" "Ecsvpcstrapi" {
  cidr_block = var.vpc_cidr_block
  tags = {
    name = "Ecs-strapi-vpc-rm"
  }
}

resource "aws_subnet" "publicsubnets" {
  count = length(var.subnetnames)
  vpc_id            = aws_vpc.Ecsvpcstrapi.id
  cidr_block        = cidrsubnet(var.vpc_cidr_block, 8, count.index)
  availability_zone = var.availabilityzones[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = var.subnetnames[count.index]
  }
}

resource "aws_internet_gateway" "strapiigw" {
  vpc_id = aws_vpc.Ecsvpcstrapi.id
  tags = {
    Name = "Ecsstrapiigw-rm"
  }
}

resource "aws_route_table" "publicroutetable" {
  vpc_id = aws_vpc.Ecsvpcstrapi.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.strapiigw.id
  }
  tags = {
    Name = "Publicroutetable-rm"
  }
}


resource "aws_route_table_association" "association" {
  count = 2
  subnet_id      = aws_subnet.publicsubnets[count.index].id
  route_table_id = aws_route_table.publicroutetable.id
}

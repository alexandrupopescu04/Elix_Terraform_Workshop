# Configure the AWS Provider
provider "aws" {
  region = "us-west-1"
  default_tags {
    tags = {
        Environment = "Sandbox"
        Owner= "Elix"
        CreatedBy ="Terraform"
    }
  }
}

# Create a VPC
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
    tags = {
        Name = "main vpc"
    }
}

resource "aws_subnet" "public_subnet" {
  vpc_id = aws_vpc.main_vpc.id
  cidr_block = "10.0.0.0/18"
  availability_zone = "us-west-1a"
    tags = {
        Name = "public subnet"
        CreatedBy = "Terraform"
    }
}

resource "aws_subnet" "private_subnet" {
  vpc_id = aws_vpc.main_vpc.id
  cidr_block = "10.0.128.0/18"
  availability_zone = "us-west-1a"
    tags = {
        Name = "private subnet"
        CreatedBy = "Terraform"
    }
}

resource "aws_internet_gateway" "internet_gateway" {
    vpc_id = aws_vpc.main_vpc.id
    tags={
        Name = "internet gateway"
        CreatedBy = "Terrafrom"
    }
}

resource "aws_eip" "lb" {
   domain = "vpc"
}

resource "aws_nat_gateway" "private_nat_gateway" {
  allocation_id = aws_eip.lb.id
  subnet_id = aws_subnet.public_subnet.id

  tags = {
    Name = "GW NAT"
  }
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
}

resource "aws_route_table" "private_route_table" {
    vpc_id = aws_vpc.main_vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_nat_gateway.private_nat_gateway.id
    }
}

resource "aws_route_table_association" "public" {
  subnet_id = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_route_table_association" "private" {
  subnet_id = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_key_pair" "key" {
  key_name = "awssec"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCVe8Oq9NTdRd2E82IHZk/UuGcdPtO0BFM95uCDzeh5CF6yq0Qh6zGI7k3oaRnvpwkgP1GlmBX4vnbN5qQmTyfvEqTzJda4hBNNidkpK1Rzfw8glJcsD/itjls62ynP2qr910bgbLlvlP0d8+O7fy4tvuWqEgwfu+t/CKxTUMsj0DQANqpzzo5sY2IHHmQBOkNz6BFqPTGnKpThBjnwd6OZ4JbbQ6P5iHe4TyURcJkF75fRl0SWT0fBiX6Dk+QEIEia1hS+An97S3v/sDBIjounfEhZAWeBJqwzG/IshGn8xThlk+g2SsjOlz5WKGWYNouDd+gW581WqrCOIFuX+kRd"
}

resource "aws_security_group" "Jumphost" {
  vpc_id = aws_vpc.main_vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "ingress_rules" {
  security_group_id = aws_security_group.Jumphost.id
  cidr_ipv4 = "0.0.0.0/0"
  from_port = 3389
  ip_protocol = "tcp"
  to_port = 3389
}

resource "aws_instance" "jumphost" {
  ami="ami-0fdf7c7a70369b831"
  instance_type = "t3.medium"
  key_name = aws_key_pair.key.id
  subnet_id = aws_subnet.public_subnet.id
  vpc_security_group_ids = [ aws_security_group.Jumphost.id ]
  associate_public_ip_address = true
}
provider "aws" {
  region = "eu-central-1"
}

data "aws_availability_zone" "available" {}

data "aws_ami" "latest_ubuntu" {
  owners      = ["099720109477"]
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

#-----------

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "My VPC"
  }
}

resource "aws_subnet" "pub_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    Name = "Public_a"
  }
  map_public_ip_on_launch = true
}

resource "aws_subnet" "pub_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = {
    Name = "Public_b"
  }
  map_public_ip_on_launch = true
}

resource "aws_subnet" "pr_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    Name = "Private_a"
  }
}

resource "aws_subnet" "pr_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = {
    Name = "Private_b"
  }
}

#---------

resource "aws_security_group" "web" {
  name       = "Dynamic Security Group"
  vpc_id     = aws_vpc.main.id
  depends_on = [aws_vpc.main]

  dynamic "ingress" {
    for_each = ["22", "8000"]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Dynamic SecurityGroup"
  }
}

#--------

resource "aws_launch_configuration" "web" {
  //  name            = "WebServer-Highly-Available-LC"
  name_prefix     = "WebServer-Highly-Available-LC-"
  image_id        = data.aws_ami.latest_ubuntu.id
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.web.id]
  user_data       = file("user_data.sh")
}

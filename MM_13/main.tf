provider "aws" {
  region = "eu-central-1"
}


data "aws_availability_zones" "available_zone" {}

data "aws_ami" "latest_amazon_linux" {
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
  availability_zone = data.aws_availability_zones.available_zone.names[0]
  tags = {
    Name = "Public_a"
  }
  map_public_ip_on_launch = true
}

resource "aws_subnet" "pub_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available_zone.names[1]
  tags = {
    Name = "Public_b"
  }
  map_public_ip_on_launch = true
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

resource "aws_security_group" "elb" {
  name       = "terraform-example-elb"
  vpc_id     = aws_vpc.main.id
  depends_on = [aws_vpc.main]
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
#--------

resource "aws_launch_configuration" "web" {
  //  name            = "WebServer-Highly-Available-LC"
  name_prefix     = "WebServer-Highly-Available-LC-"
  image_id        = data.aws_ami.latest_amazon_linux.id
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.web.id]
  user_data       = file("user_data.sh")
}

resource "aws_autoscaling_group" "web" {
  name                 = "ASG-${aws_launch_configuration.web.name}"
  launch_configuration = aws_launch_configuration.web.name
  min_size             = 1
  desired_capacity     = 2
  max_size             = 4
  health_check_type    = "ELB"
  vpc_zone_identifier  = [aws_subnet.pub_a.id, aws_subnet.pub_b.id]
  load_balancers       = [aws_elb.web.name]
  dynamic "tag" {
    for_each = {
      Name   = "WebServer in ASG"
      TAGKEY = "TAGVALUE"
    }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_elb" "web" {
  name            = "WebServer-HA-ELB"
  security_groups = [aws_security_group.elb.id]
  subnets         = [aws_subnet.pub_a.id, aws_subnet.pub_b.id]
  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = 8000
    instance_protocol = "http"
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:8000/"
    interval            = 30
  }
  tags = {
    Name = "WebServer-Highly-Available-ELB"
  }
}


#------------

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}

#------------

/* Routing table for public subnet */
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

#---------------

/* Route table associations */
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.pub_a.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.pub_b.id
  route_table_id = aws_route_table.public.id
}

#--------------

output "elb_dns_name" {
  value = aws_elb.web.dns_name
}

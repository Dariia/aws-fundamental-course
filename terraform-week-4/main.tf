resource "aws_security_group" "ssh" {
  name = "ssh"
  description = "Allow incoming SSH connections."
  vpc_id = aws_vpc.prod.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "http" {
  name = "http"
  description = "Allow incoming HTTP connections."
  vpc_id = aws_vpc.prod.id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.prod.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-west-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public"
  }
}

resource "aws_subnet" "private" {
  vpc_id = aws_vpc.prod.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-west-2a"

  tags = {
    Name = "Private"
  }
}
resource "aws_instance" "web_public" {
  ami = "${lookup(var.amis, var.aws_region)}"
  instance_type = "t2.micro"
  key_name = "${var.aws_key_name}"
  subnet_id = aws_subnet.public.id

  security_groups = [aws_security_group.ssh.id, aws_security_group.http.id]
  user_data = file("script.sh")
  depends_on = [aws_security_group.http, aws_security_group.ssh]
}

resource "aws_instance" "web_private" {
  ami = "${lookup(var.amis, var.aws_region)}"
  instance_type = "t2.micro"
  key_name = "${var.aws_key_name}"
  subnet_id = aws_subnet.private.id
  security_groups = [aws_security_group.ssh.id, aws_security_group.http.id]
  user_data = file("script-private.sh")
  depends_on = [aws_security_group.http, aws_security_group.ssh]
}

resource "aws_vpc" "prod" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "prod vpc"
  }
}

resource "aws_internet_gateway" "gw_main" {
  vpc_id = aws_vpc.prod.id
}

resource "aws_route_table" "prod" {
  vpc_id = aws_vpc.prod.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw_main.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.gw_main.id
  }

  tags = {
    Name = "prod"
  }
}

resource "aws_route_table_association" "prod" {
  subnet_id = aws_subnet.public.id
  route_table_id = aws_route_table.prod.id
}

resource "aws_eip" "prod" {
  vpc = true
}

resource "aws_nat_gateway" "gw_nat" {
  depends_on = [aws_subnet.public, aws_eip.prod]
  allocation_id = aws_eip.prod.id
  subnet_id = aws_subnet.public.id
}

resource "aws_route_table" "nat" {
  vpc_id = aws_vpc.prod.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.gw_nat.id
  }

  tags = {
    Name = "nat"
  }
}

resource "aws_route_table_association" "nat" {
  subnet_id = aws_subnet.private.id
  route_table_id = aws_route_table.nat.id
  depends_on = [aws_subnet.private, aws_route_table.nat]
}

locals {
  ingress_rules = [
    {
      name = "HTTPS"
      port = 443
      description = "Ingress rules for port 443"
    },
    {
      name = "HTTP"
      port = 80
      description = "Ingress rules for port 80"
    },
    {
      name = "SSH"
      port = 22
      description = "Ingress rules for port 22"
    }]

}
resource "aws_security_group" "elb" {
  name = "CustomSG"
  description = "Allow TLS inbound traffic"
  vpc_id = aws_vpc.prod.id
  egress = [
    {
      description = "for all outgoing traffics"
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids = []
      security_groups = []
      self = false
    }
  ]

  dynamic "ingress" {
    for_each = local.ingress_rules

    content {
      description = ingress.value.description
      from_port = ingress.value.port
      to_port = ingress.value.port
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  tags = {
    Name = "AWS security group dynamic block"
  }
}

resource "aws_lb" "prod" {
  name = "prod"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.elb.id]
  subnets = [aws_subnet.public.id, aws_subnet.private.id]

  tags = {
    Environment = "production"
  }
}

resource "aws_lb_target_group" "prod" {
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.prod.id
  name = "prod"
}

resource "aws_lb_listener" "prod" {
  load_balancer_arn = aws_lb.prod.arn
  port = 80

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.prod.arn
  }
}

data "aws_lb_target_group" "prod" {
  name = "prod"
  depends_on = [aws_lb_target_group.prod]
}

resource "aws_lb_target_group_attachment" "web_public" {
  target_group_arn = aws_lb_target_group.prod.arn
  target_id = aws_instance.web_public.id
  port = 80
}

resource "aws_lb_target_group_attachment" "web_private" {
  target_group_arn = aws_lb_target_group.prod.arn
  target_id = aws_instance.web_private.id
  port = 80
}

output "lb_url" {
  description = "URL of load balancer"
  value = "http://${aws_lb.prod.dns_name}/"
}

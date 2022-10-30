resource "aws_security_group" "ssh" {
  name = "ssh"
  description = "Allow incoming SSH connections."

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

resource "aws_security_group" "postgress" {
  name        = "postgress"
  description = "Allow postgress inbound traffic"

  ingress {
    description      = "Postgress"
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_postgress"
  }
}

resource "aws_security_group" "http" {
  name = "http"
  description = "Allow incoming HTTP connections."

  ingress {
    from_port = 80
    to_port = 80
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

resource "aws_iam_role" "web" {
  name = "web"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "web" {
  name = "web"
  role = "${aws_iam_role.web.id}"
}

resource "aws_iam_role_policy" "web" {
  name = "web"
  role = "${aws_iam_role.web.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Action": [
            "s3:*"
        ],
        "Effect": "Allow",
        "Resource": [
            "*"
        ]
    },
    {
        "Action": [
            "dynamodb:*"
        ],
        "Effect": "Allow",
        "Resource": [
            "*"
        ]
    },
    {
        "Action": [
            "rds-db:*"
        ],
        "Effect": "Allow",
        "Resource": [
            "*"
        ]
    }
  ]
}
EOF
}

data "template_file" "user_data" {
  template = "${file("download-files.sh")}"

  vars = {
    aws_s3_bucket = "${var.bucket_name}"
  }
}

resource "random_string" "password" {
  length  = 32
  upper   = true
  numeric  = true
  special = false
}

resource "aws_db_instance" "web" {
  identifier             = "web"
  db_name                = "web"
  instance_class         = "db.t3.micro"
  allocated_storage      = 5
  engine                 = "postgres"
  engine_version         = "12"
  skip_final_snapshot    = true
  publicly_accessible    = true
  vpc_security_group_ids = [aws_security_group.ssh.id, aws_security_group.postgress.id]
  username               = "dariia"
  password               = "451Robots"
}

resource "aws_dynamodb_table" "web" {
  name           = "web"
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "UserId"
  range_key      = "UserName"

  attribute {
    name = "UserId"
    type = "N"
  }

  attribute {
    name = "UserName"
    type = "S"
  }

  ttl {
    attribute_name = "TimeToExist"
    enabled        = false
  }
}

resource "aws_instance" "web" {
  ami = "${lookup(var.amis, var.aws_region)}"
  instance_type = "t2.micro"
  key_name = "${var.aws_key_name}"
  security_groups = [
    "${aws_security_group.ssh.name}",
    "${aws_security_group.http.name}",
    "${aws_security_group.postgress.name}"
  ]
  user_data = templatefile("script.tftpl", { aws_s3_bucket = "${var.bucket_name}" })
  iam_instance_profile = "${aws_iam_instance_profile.web.id}"
}

output "ec2_public_ip" {
  value = "${aws_instance.web.public_ip}"
}

output "rds_endpoint" {
  value = "${aws_db_instance.web.endpoint}"
}

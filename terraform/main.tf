resource "aws_security_group" "ssh-security-group" {
  name = "ssh-security-group"
  description = "Allow incoming SSH connections."

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
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

resource "aws_security_group" "http-security-group" {
  name = "http-security-group"
  description = "Allow incoming HTTP connections."

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "web_iam_role" {
  name = "web_iam_role"
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

resource "aws_iam_instance_profile" "web_instance_profile" {
  name = "web_instance_profile_2"
  role = "${aws_iam_role.web_iam_role.id}"
}

resource "aws_iam_role_policy" "web_iam_role_policy" {
  name = "web_iam_role_policy"
  role = "${aws_iam_role.web_iam_role.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": ["arn:aws:s3:::ddrobotk-testbucket"]
    },
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": ["arn:aws:s3:::ddrobotk-testbucket/*"]
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

resource "aws_instance" "web-instance" {
  ami = "${lookup(var.amis, var.aws_region)}"
  instance_type = "t2.micro"
  key_name = "${var.aws_key_name}"
  security_groups = [
    "${aws_security_group.ssh-security-group.name}",
    "${aws_security_group.http-security-group.name}"
  ]
  user_data = "${data.template_file.user_data.rendered}"
  iam_instance_profile = "${aws_iam_instance_profile.web_instance_profile.id}"
}

output "ec2_public_ip" {
  value = "${aws_instance.web-instance.public_ip}"
}

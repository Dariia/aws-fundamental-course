resource "aws_security_group" "ssh" {
  name = "ssh-security-group"
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

// ----- SNS ------ //
resource "aws_sns_topic" "results_updates" {
  name = "results-updates-topic"
}

resource "aws_sns_topic_subscription" "results_updates_sqs_target" {
  topic_arn = "${aws_sns_topic.results_updates.arn}"
  protocol  = "email"
  endpoint  = "drobotcko@gmail.com"
}

// ----- SQS ------ //

resource "aws_sqs_queue" "results_updates_dl_queue" {
  name = "results-updates-dl-queue"
}

resource "aws_sqs_queue" "results_updates_queue" {
  name = "results-updates-queue"
  redrive_policy  = "{\"deadLetterTargetArn\":\"${aws_sqs_queue.results_updates_dl_queue.arn}\",\"maxReceiveCount\":5}"
  visibility_timeout_seconds = 300

  tags = {
    Environment = "dev"
  }
}

resource "aws_sqs_queue_policy" "ec2" {
  queue_url = "${aws_sqs_queue.results_updates_queue.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Sid": "First",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:SendMessage",
      "Resource": "${aws_sqs_queue.results_updates_queue.arn}",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "${aws_sns_topic.results_updates.arn}"
        }
      }
    }
  ]
}
POLICY
}

resource "aws_iam_role" "ec2" {
  name = "ec2_iam_role"
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

resource "aws_iam_role_policy_attachment" "sqs" {
  role       = "${aws_iam_role.ec2.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSFullAccess"
}

resource "aws_iam_role_policy_attachment" "sns" {
  role       = "${aws_iam_role.ec2.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "ec2_instance_profile"
  role = "${aws_iam_role.ec2.id}"
}

// ---- Instance ----- //

resource "aws_instance" "web" {
  ami = "${lookup(var.amis, var.aws_region)}"
  instance_type = "t2.micro"
  key_name = "${var.aws_key_name}"
  security_groups = [aws_security_group.ssh.name]
  depends_on = [aws_security_group.ssh]
  iam_instance_profile = "${aws_iam_instance_profile.ec2.id}"
}

output "sqs_arn" {
  value = "${aws_sqs_queue.results_updates_queue.arn}"
}

output "sns_arn" {
  value = "${aws_sns_topic.results_updates.arn}"
}

output "ec2_public_ip" {
  value = "${aws_instance.web.public_ip}"
}

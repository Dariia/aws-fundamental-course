variable "bucket_name" {
  default = "ddrobotk-testbucket"
}

variable "bucket_arn" {
  default = "arn:aws:s3:::ddrobotk-testbucket"
}

variable "acl_value" {
  default = "private"
}

variable "aws_region" {
  default = "us-west-2"
}

variable "aws_access_key" {
  type = string
}
variable "aws_secret_key" {
  type = string
}

variable "aws_key_name" {
  default = "my-key"
}

variable "amis" {
  default = {
    us-west-2 = "ami-08e2d37b6a0129927"
  }
}

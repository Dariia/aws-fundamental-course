#!/bin/bash
sudo yum -y install aws-cli
aws s3 cp s3://${aws_s3_bucket}/myfile.txt .

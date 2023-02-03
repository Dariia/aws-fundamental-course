#!/bin/bash
sudo yum -y install aws-cli
aws s3 cp s3://${aws_s3_bucket}/rds-script.sql ./init/
aws s3 cp s3://${aws_s3_bucket}/dynamodb-script.sh ./init/

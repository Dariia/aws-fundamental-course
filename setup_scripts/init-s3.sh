#!/bin/bash

aws s3 mb s3://ddrobotk-testbucket --region=us-west-2
aws s3api put-bucket-versioning --bucket ddrobotk-testbucket --versioning-configuration Status=Enabled
aws s3 cp rds-script.sql s3://ddrobotk-testbucket/
aws s3 cp dynamodb-script.sh s3://ddrobotk-testbucket/


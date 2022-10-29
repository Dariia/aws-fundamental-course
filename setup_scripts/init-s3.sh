#!/usr/bin/env bash

aws s3 mb s3://ddrobotk-testbucket --region=us-west-2
aws s3api put-bucket-versioning --bucket ddrobotk-testbucket1 --versioning-configuration Status=Enabled
echo This is some text > myfile.txt
aws s3 cp myfile.txt s3://ddrobotk-testbucket/


#!/bin/bash
aws dynamodb list-tables --region us-west-2

echo "put (key -> '1' value -> 'Dariia')"
aws dynamodb put-item --table-name "web" --item '{"UserId": {"N": "1"}, "UserName": { "S": "Daria" }}' --region us-west-2
echo "put (key -> '2' value -> 'Alex')"
aws dynamodb put-item --table-name "web" --item '{"UserId": {"N": "2"}, "UserName": { "S": "Alex" }}' --region us-west-2

echo "get value with key -> '1'"
aws dynamodb get-item --table-name "web" --key '{"UserName": { "S": "Daria" }, "UserId": { "N": "1"}}' --region us-west-2
echo "get value with key -> '2'"
aws dynamodb get-item --table-name "web" --key '{"UserName": {"S": "Alex"}, "UserId": {"N": "2"}}' --region us-west-2

echo "get not existed value"
aws dynamodb get-item --table-name "web" --key '{"UserName": {"S": "Alex1"}, "UserId": {"N": "20"}}' --region us-west-2

echo "scan table"
aws dynamodb scan --table-name web  --region us-west-2

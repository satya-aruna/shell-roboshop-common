#!/bin/bash

SG_ID="sg-05b94ced162e1d820"    # Security group ID  taken from AWS console
AMI_ID="ami-0220d79f3f480ecf5"  # AMI ID taken from AWS console
INSTANCE_TYPE="t3.micro"
HOSTED_ZONEID="Z0542579J1GOAFY7EM5S"
DOMAIN_NAME="asadaws2026.online"

for instance in $@
do
    INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --security-group-ids $SG_ID \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance}]" \
    --query 'Instances[0].InstanceId' \
    --output text)   

    if [ $instance == "frontend" ]; then
        IP=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --query 'Reservations[*].Instances[*].[PublicIpAddress]' \
        --output text)
        RECORD_NAME="$DOMAIN_NAME"
    else
        IP=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --query 'Reservations[*].Instances[*].[PrivateIpAddress]' \
        --output text)
        RECORD_NAME="$instance.$DOMAIN_NAME"
    fi

    echo "IP address: $IP"

    aws route53 change-resource-record-sets \
    --hosted-zone-id "$HOSTED_ZONEID" \
    --change-batch '
    {
    "Comment": "Update record to reflect new IP address",
    "Changes": [
        {
        "Action": "UPSERT",
        "ResourceRecordSet": {
            "Name": "'$RECORD_NAME'",
            "Type": "A",
            "TTL": 1,
            "ResourceRecords": [
            {
                "Value": "'$IP'"
            }
            ]
        }
        }
    ]
    }'

    echo "Record updated for $instance"

done
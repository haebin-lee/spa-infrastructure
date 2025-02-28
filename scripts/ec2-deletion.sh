#!/bin/bash
# cleanup.sh - Script to terminate EC2 instance and delete security group

# Use provided AWS_REGION or default to us-east-1
AWS_REGION=${AWS_REGION:-us-east-1}

echo "Cleaning up resources..."
echo "Instance ID: $INSTANCE_ID"
echo "Security Group: $SG_ID"
echo "Region: $AWS_REGION"

# Terminate instance
echo "Terminating instance..."
aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $AWS_REGION > /dev/null

# Wait for instance to terminate
echo "Waiting for instance to terminate..."
aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID --region $AWS_REGION

# Delete security group
echo "Deleting security group..."
aws ec2 revoke-security-group-ingress --group-id $DB_SG_ID --protocol tcp --port 3306 --source-group $SG_ID --region $AWS_REGION
aws ec2 delete-security-group --group-id $SG_ID --region $AWS_REGION > /dev/null

echo "Cleanup complete!"
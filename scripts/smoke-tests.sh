#!/bin/bash
# Script to run smoke tests on an EC2 instance
set -e  # Exit immediately if a command exits with a non-zero status

# Test frontend
echo "Testing frontend availability..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://$PUBLIC_IP:3000/)
if [ "$HTTP_STATUS" -eq 200 ]; then
  echo "✅ Frontend test passed - HTTP status 200 OK"
else
  echo "❌ Frontend test failed - received HTTP status $HTTP_STATUS from http://localhost:3000/"
  echo "SMOKE_TEST_RESULT=FAILED"
  exit 1
fi

# Test backend health
echo "Testing backend health endpoint..."
BACKEND_TEST=$(curl -s http://$PUBLIC_IP:8080/health | grep -q '{"status":"ok","result":1}' && echo 'SUCCESS' || echo 'FAILED')
if [ "$BACKEND_TEST" = "SUCCESS" ]; then
  echo "✅ Backend health test passed"
else
  echo "❌ Backend health test failed"
  echo "SMOKE_TEST_RESULT=FAILED"
  exit 1
fi

echo "SMOKE_TEST_RESULT=SUCCESS"
echo "All smoke tests passed successfully! 🎉"

echo "Pushing images to ECR..."

# Tag with ECR tags
echo "Tagging images..."
docker tag local:frontend $ECR_REPO:frontend
docker tag local:backend $ECR_REPO:backend

# Push to ECR
echo "Pushing images to ECR..."
docker push $ECR_REPO:frontend
docker push $ECR_REPO:backend

echo "Successfully pushed images to ECR 🚀"
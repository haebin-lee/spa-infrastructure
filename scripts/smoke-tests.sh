#!/bin/bash
# Script to run smoke tests on an EC2 instance
set -e  # Exit immediately if a command exits with a non-zero status

# Test frontend
echo "Testing frontend availability..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://$public_ip:3000/)
if [ "$HTTP_STATUS" -eq 200 ]; then
  echo "✅ Frontend test passed - HTTP status 200 OK"
else
  echo "❌ Frontend test failed - received HTTP status $HTTP_STATUS from http://localhost:3000/"
  echo "SMOKE_TEST_RESULT=FAILED"
  exit 1
fi

# Test backend health
echo "Testing backend health endpoint..."
BACKEND_TEST=$(curl -s http://$public_ip:8080/health | grep -q '{"status":"ok","result":1}' && echo 'SUCCESS' || echo 'FAILED')
if [ "$BACKEND_TEST" = "SUCCESS" ]; then
  echo "✅ Backend health test passed"
else
  echo "❌ Backend health test failed"
  echo "SMOKE_TEST_RESULT=FAILED"
  exit 1
fi

echo "SMOKE_TEST_RESULT=SUCCESS"
echo "All smoke tests passed successfully! 🎉"
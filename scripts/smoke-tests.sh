#!/bin/bash
# Script to run smoke tests on an EC2 instance
set -e  # Exit immediately if a command exits with a non-zero status

# Test backend health directly
echo "Testing backend health endpoint directly..."
BACKEND_TEST=$(curl -s http://$PUBLIC_IP:8080/api/health | grep -q '{"status":"ok","result":1}' && echo 'SUCCESS' || echo 'FAILED')
if [ "$BACKEND_TEST" = "SUCCESS" ]; then
  echo "✅ Backend health test passed directly"
else
  echo "❌ Backend health test failed directly"
  echo "SMOKE_TEST_RESULT=FAILED"
  exit 1
fi

echo "Checking frontend API test page at http://$PUBLIC_IP:3000/client-api/debug"
DEBUG_RESPONSE=$(curl -s http://$PUBLIC_IP:3000/client-api/debug)
if echo "$DEBUG_RESPONSE" | grep -q '"status":"ok"'; then
  echo "✅ Frontend API test page exists and contains the expected title"
else
  echo "❌ Frontend API test page doesn't contain the expected title"
  echo "SMOKE_TEST_RESULT=FAILED"
  exit 1
fi

echo "SMOKE_TEST_RESULT=SUCCESS"
echo "All smoke tests passed successfully! 🎉"
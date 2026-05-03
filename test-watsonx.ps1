# Test watsonx.ai Connection
# This script tests your watsonx.ai setup

Write-Host "Testing watsonx.ai connection..." -ForegroundColor Cyan
Write-Host ""

# Get IAM token
Write-Host "Getting IAM token..." -ForegroundColor Yellow
$tokenOutput = ibmcloud iam oauth-tokens
$token = ($tokenOutput | Select-String "Bearer").ToString().Trim()

# Prepare the request
$url = "https://jp-tok.ml.cloud.ibm.com/ml/v1/text/generation?version=2023-05-29"
$projectId = "e33f9d2e-aaef-493f-9363-b4720c98ddbe"

$body = @{
    model_id = "ibm/granite-13b-chat-v2"
    input = "Hello from Philippines! Tell me a fun fact about Manila."
    parameters = @{
        max_new_tokens = 100
    }
    project_id = $projectId
} | ConvertTo-Json

# Make the API call
Write-Host "Calling watsonx.ai API..." -ForegroundColor Yellow
Write-Host ""

try {
    $response = Invoke-RestMethod -Uri $url -Method Post -Headers @{
        "Authorization" = $token
        "Content-Type" = "application/json"
    } -Body $body
    
    Write-Host "✅ SUCCESS! watsonx.ai is working!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Response from AI:" -ForegroundColor Cyan
    Write-Host $response.results[0].generated_text -ForegroundColor White
    Write-Host ""
    Write-Host "🎉 Phase 0 is COMPLETE! You're ready to start coding!" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Error connecting to watsonx.ai" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Make sure your Project ID is correct in .env file"
    Write-Host "2. Check that you have access to the project in watsonx.ai"
    Write-Host "3. Verify your IAM token is valid (run: ibmcloud iam oauth-tokens)"
}

# Made with Bob

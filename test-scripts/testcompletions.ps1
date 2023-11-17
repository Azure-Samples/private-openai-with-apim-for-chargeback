# variables
$apimServiceName = "apim-xxxxxxxx"
$apimSubscriptionKey = "xxxxxxxxxxxxxxx"
$openAiDeploymentId = "gpt-35"
$azureOpeAiApiVersion = "2023-05-15"
$max_tokens = 100
$temperature = 0.9
$stream = "false" # true or false


$completionsApi = "https://$apimServiceName.azure-api.net/openai/deployments/$openAiDeploymentId/completions?api-version=$azureOpeAiApiVersion"
# echo $completionsApi

$completions_request = @"
{
    `"prompt`":`"Once upon a time`",
    `"max_tokens`": $max_tokens, 
    `"temperature`": $temperature, 
    `"stream`": $stream
}
"@
# echo $completions_request

$headers = @{"Ocp-Apim-Subscription-Key"=$apimSubscriptionKey;"Content-Type"="application/json"}

$response = Invoke-RestMethod $completionsApi -Method 'POST' -Headers $headers -Body $completions_request
$response | ConvertTo-Json

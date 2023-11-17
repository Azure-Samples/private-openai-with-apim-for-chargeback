
#variables
apimServiceName="apim-xxxxxxxxxx"
apimSubscriptionKey="xxxxxxxxxxxxxxxx" 
openAiDeploymentId="gpt-35"
azureOpeAiApiVersion="2023-05-15"
max_tokens=100
temperature=0.9
stream=false # true or false

chatCompletionsApi="https://$apimServiceName.azure-api.net/openai/deployments/$openAiDeploymentId/chat/completions?api-version=$azureOpeAiApiVersion"
# echo $chatCompletionsApi

chatCompletions_request='{
    "messages":[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Does Azure OpenAI support customer managed keys?"},
        {"role": "assistant", "content": "Yes, customer managed keys are supported by Azure OpenAI."},
        {"role": "user", "content": "Do other Azure AI services support this too?"}
    ],
    "max_tokens": '$max_tokens', 
    "temperature": '$temperature', 
    "stream": '$stream'
}'

# echo $chatCompletions_request
curl -X POST $chatCompletionsApi \
    -H "Ocp-Apim-Subscription-Key: $apimSubscriptionKey" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "$chatCompletions_request"
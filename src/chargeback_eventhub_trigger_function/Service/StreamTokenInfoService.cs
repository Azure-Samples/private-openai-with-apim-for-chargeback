using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Newtonsoft.Json.Linq;
using chargeback_eventhub_trigger.Model;


namespace chargeback_eventhub_trigger.Service
{
    public class StreamTokenInfoService : ITokenCalculationService
    {
        public int CalculatePromptTokens(OpenAiApiEvent openAiApiEvent)
        {
            var promptTokens = 0;

            var requestJson = JObject.Parse(openAiApiEvent.Request);

            if (openAiApiEvent.ApiOperation == OpenAiOperationEnum.TextCompletion)
                promptTokens = GetTokenizerCount((string)requestJson["prompt"]);
            else
            {
                if (requestJson["messages"] != null && requestJson["messages"].HasValues)
                    promptTokens = requestJson["messages"].Sum(message => GetTokenizerCount((string)message["content"]));
            }

            return promptTokens;
        }

        public async Task<int> CalculateCompletionTokens(OpenAiApiEvent openAiApiEvent)
        {
            var responseChunks = ReadChatCompletionChunks(openAiApiEvent.Response);
            var completionTokenCount = 0;

            await foreach (var item in responseChunks)
            {
                var dataStr = item;
                dataStr = dataStr.Replace("data:", "").Trim();
                if (string.IsNullOrEmpty(item) || dataStr.Equals("[DONE]"))
                    continue;

                var responseChunk = JObject.Parse(dataStr);

                if (responseChunk["choices"] == null || !responseChunk["choices"].HasValues) continue;

                var responseText = openAiApiEvent.ApiOperation == OpenAiOperationEnum.TextCompletion
                    ? responseChunk["choices"].FirstOrDefault()?["text"]?.ToString()
                    : responseChunk["choices"].FirstOrDefault()?["delta"]?["content"]?.ToString();


                completionTokenCount += GetTokenizerCount(responseText);
            }

            return completionTokenCount;
        }
        

        static async IAsyncEnumerable<string> ReadChatCompletionChunks(string response)
        {
            using var reader = new StreamReader(new MemoryStream(System.Text.Encoding.UTF8.GetBytes(response)));
            while (!reader.EndOfStream)
            {
                yield return await reader.ReadLineAsync();
            }
        }

        //https://github.com/openai/openai-cookbook/blob/main/examples/How_to_count_tokens_with_tiktoken.ipynb
        //https://github.com/tryAGI/Tiktoken
        static int GetTokenizerCount(string input)
        {
            if(string.IsNullOrEmpty(input))
                return 0;
            //var encoding = Tiktoken.Encoding.ForModel("gpt-3.5-turbo");            
            var encoding = Tiktoken.Encoding.Get(Tiktoken.Encodings.Cl100KBase);
            var tokens = encoding.Encode(input);
            return tokens.Count;
        }
    }
}

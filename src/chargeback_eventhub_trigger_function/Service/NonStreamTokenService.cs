using Newtonsoft.Json.Linq;
using System.Threading.Tasks;
using chargeback_eventhub_trigger.Model;

namespace chargeback_eventhub_trigger.Service
{
    public class NonStreamTokenService : ITokenCalculationService
    {
        public int CalculatePromptTokens(OpenAiApiEvent openAiApiEvent)
        {
            var responseObject = JObject.Parse(openAiApiEvent.Response);
            return (int)responseObject["usage"]?["prompt_tokens"];
        }

        public async Task<int> CalculateCompletionTokens(OpenAiApiEvent openAiApiEvent)
        {
            var responseObject = JObject.Parse(openAiApiEvent.Response);
            var completionTokens = (int)responseObject["usage"]?["completion_tokens"];
            return await Task.FromResult<int>(completionTokens);
        }    
    }
}

using System.Threading.Tasks;
using chargeback_eventhub_trigger.Model;

namespace chargeback_eventhub_trigger.Service
{
    public interface ITokenCalculationService
    {
        
        int CalculatePromptTokens(OpenAiApiEvent openAiApiEvent);

        Task<int> CalculateCompletionTokens(OpenAiApiEvent openAiApiEvent);

    }
}

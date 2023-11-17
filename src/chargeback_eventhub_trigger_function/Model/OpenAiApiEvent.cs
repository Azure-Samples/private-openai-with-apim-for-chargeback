using Newtonsoft.Json.Converters;
using System.Text.Json.Serialization;


namespace chargeback_eventhub_trigger.Model
{
    public class OpenAiApiEvent
    {
        public string EventTime { get; set; }

        [JsonConverter(typeof(StringEnumConverter))]
        public OpenAiOperationEnum? ApiOperation { get; set; }
        public string AppSubscriptionKey { get; set; }

        public string Request { get; set; }

        public string Response { get; set; }
    }


    public enum OpenAiOperationEnum
    {
        ChatCompletion,
        TextCompletion,


    }
}

using System;
using System.Collections.Generic;

namespace chargeback_eventhub_trigger.Model
{
    public class TokenInfo
    {
        public string TokenInfoId => Guid.NewGuid().ToString();
        public OpenAiOperationEnum ApiOperation { get; set; }
        public string AppKey { get; set; }

        public string Timestamp { get; set; }

        public bool Stream { get; set; }
        public int PromptTokens { get; set; }

        public int CompletionTokens { get; set; }

        public int TotalTokens => PromptTokens + CompletionTokens;


        public Dictionary<string, string> ToDictionary()
        {
            var dict = new Dictionary<string, string>
            {
                { "TokenInfoId", TokenInfoId },
                { "ApiOperation", ApiOperation.ToString()},
                { "AppKey", AppKey },
                { "Timestamp", Timestamp },
                { "Stream", Stream.ToString() },
                { "PromptTokens", PromptTokens.ToString() },
                { "CompletionTokens", CompletionTokens.ToString() },
                { "TotalTokens", TotalTokens.ToString() },
            };
            return dict;
        }
    }
}

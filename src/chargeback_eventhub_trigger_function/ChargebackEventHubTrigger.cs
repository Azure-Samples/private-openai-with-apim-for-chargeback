using System;
using System.Collections.Generic;
using Azure.Messaging.EventHubs;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.ApplicationInsights;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using chargeback_eventhub_trigger.Model;
using chargeback_eventhub_trigger.Service;
using Newtonsoft.Json.Linq;
using Newtonsoft.Json;

namespace chargeback_eventhub_trigger
{
    public class ChargebackEventHubTrigger
    {
        private readonly TokenServiceFactory _tokenServiceFactory;
        private readonly ILogger _logger;
        private TelemetryClient _telemetryClient;


        public ChargebackEventHubTrigger(TokenServiceFactory tokenServiceFactory, TelemetryClient telemetryClient, ILoggerFactory loggerFactory)
        {
            _tokenServiceFactory = tokenServiceFactory;
            _telemetryClient = telemetryClient;
            _logger = loggerFactory.CreateLogger<ChargebackEventHubTrigger>();

        }

        [Function("ChargebackEventHubTrigger")]
        public async Task Run([EventHubTrigger("%EventHubName%", Connection = "EventHubConnection")] string[] openAiApiEvents)
        {
            var exceptions = new List<Exception>();

            //Eventhub Messages arrive as an array            
            foreach (var eventData in openAiApiEvents)
            {
                try
                {
                    var openAiApiEvent = JsonConvert.DeserializeObject<OpenAiApiEvent>(eventData);

                    if (openAiApiEvent?.Response == null || openAiApiEvent.ApiOperation == null)
                    {
                        _logger.LogWarning($"Invalid OpenAi Api Event. Skipping.");
                        continue;
                    }

                    var requestObject = JObject.Parse(openAiApiEvent.Request);
                    var isStream = false;
                    if (requestObject.TryGetValue("stream", out JToken? steamToken))
                    {
                        isStream = (bool)steamToken;
                    }

                    var tokenService = _tokenServiceFactory.GetStreamService(isStream);

                    var tokenInfo = new TokenInfo()
                    {
                        ApiOperation = openAiApiEvent.ApiOperation.GetValueOrDefault(),
                        AppKey = openAiApiEvent.AppSubscriptionKey,
                        Timestamp = openAiApiEvent.EventTime,
                        Stream = isStream,
                        PromptTokens = tokenService.CalculatePromptTokens(openAiApiEvent),
                        CompletionTokens = await tokenService.CalculateCompletionTokens(openAiApiEvent)
                    };

                    _logger.LogInformation($"Azure OpenAI Tokens Calculated: {JsonConvert.SerializeObject(tokenInfo)}");

                    _telemetryClient.TrackEvent("Azure OpenAI Tokens", tokenInfo.ToDictionary());
                }
                catch (Exception e)
                {
                    // We need to keep processing the rest of the batch - capture this exception and continue.
                    // Also, consider capturing details of the message that failed processing so it can be processed again later.
                    exceptions.Add(e);
                }
            }

            // Once processing of the batch is complete, if any messages in the batch failed processing throw an exception so that there is a record of the failure.

            if (exceptions.Count > 1)
                throw new AggregateException(exceptions);

            if (exceptions.Count == 1)
                throw exceptions.Single();

            await Task.FromResult(true);


        }
    }
}

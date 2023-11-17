using chargeback_eventhub_trigger.Service;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using System.Threading.Tasks;

namespace chargeback_eventhub_trigger
{
    class Program
    {
        static async Task Main(string[] args)
        {
            var host = new HostBuilder()
                .ConfigureFunctionsWorkerDefaults()
                .ConfigureServices(services =>
                {
                    services.AddApplicationInsightsTelemetryWorkerService();
                    services.ConfigureFunctionsApplicationInsights();

                    services.AddSingleton<TokenServiceFactory>();

                    services.AddSingleton<StreamTokenInfoService>()
                    .AddSingleton<ITokenCalculationService, StreamTokenInfoService>(s => s.GetService<StreamTokenInfoService>());

                    services.AddSingleton<NonStreamTokenService>()
                    .AddSingleton<ITokenCalculationService, NonStreamTokenService>(s => s.GetService<NonStreamTokenService>());
                })
                .Build();

            await host.RunAsync();
           
        }
    }
    }


            
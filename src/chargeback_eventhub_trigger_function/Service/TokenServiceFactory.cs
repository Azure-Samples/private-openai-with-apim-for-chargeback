using System;

namespace chargeback_eventhub_trigger.Service
{
    public class TokenServiceFactory
    {
        private readonly IServiceProvider serviceProvider;

        public TokenServiceFactory(IServiceProvider serviceProvider)
        {
            this.serviceProvider = serviceProvider;
        }

        public ITokenCalculationService GetStreamService(bool isStream)
        {
            return isStream ? (ITokenCalculationService)serviceProvider.GetService(typeof(StreamTokenInfoService)) 
                : (ITokenCalculationService)serviceProvider.GetService(typeof(NonStreamTokenService));

            
        }
    }
}

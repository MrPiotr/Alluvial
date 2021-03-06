using System;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using Alluvial.Distributors;

namespace Alluvial
{
    public class InMemoryStreamQueryDistributor : StreamQueryDistributorBase
    {
        private static readonly ConcurrentDictionary<string, ConcurrentDictionary<LeasableResource, Lease>> workInProgressGlobal =
            new ConcurrentDictionary<string, ConcurrentDictionary<LeasableResource, Lease>>();

        private readonly ConcurrentDictionary<LeasableResource, Lease> workInProgress;

        public InMemoryStreamQueryDistributor(
            LeasableResource[] leasableResources,
            string scope,
            int maxDegreesOfParallelism = 5,
            TimeSpan? waitInterval = null) :
                base(leasableResources,
                     maxDegreesOfParallelism,
                     waitInterval)
        {
            if (scope == null)
            {
                throw new ArgumentNullException("scope");
            }
            workInProgress = workInProgressGlobal.GetOrAdd(scope, s => new ConcurrentDictionary<LeasableResource, Lease>());
        }

        protected override async Task<Lease> AcquireLease()
        {
            var now = DateTimeOffset.UtcNow;

            var resource = leasableResources
                .Where(l => l.LeaseLastReleased + waitInterval < now)
                .OrderBy(l => l.LeaseLastReleased)
                .FirstOrDefault(l => !workInProgress.ContainsKey(l));

            if (resource == null)
            {
                return null;
            }

            var lease = new Lease(resource,
                                  resource.DefaultLeaseDuration);

            if (workInProgress.TryAdd(resource, lease))
            {
                lease.LeasableResource.LeaseLastGranted = now;

                return lease;
            }

            return null;
        }

        protected override async Task ReleaseLease(Lease lease)
        {
            lease.NotifyCompleted();

            if (!workInProgress.Values.Any(l => l.GetHashCode().Equals(lease.GetHashCode())))
            {
                Debug.WriteLine("[Distribute] ReleaseLease (failed): " + lease);
                return;
            }

            Lease _;

            if (workInProgress.TryRemove(lease.LeasableResource, out _))
            {
                lease.LeasableResource.LeaseLastReleased = DateTimeOffset.UtcNow;
                Debug.WriteLine("[Distribute] ReleaseLease: " + lease);
            }
        }
    }
}
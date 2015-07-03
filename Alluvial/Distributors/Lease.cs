using System;
using System.Threading;
using System.Threading.Tasks;

namespace Alluvial.Distributors
{
    public class Lease
    {
        private readonly CancellationTokenSource cancellationTokenSource = new CancellationTokenSource();
        private readonly LeasableResource leasableResource;
        private readonly dynamic ownerToken;
        private bool completed = false;
        private TimeSpan duration;

        public Lease(LeasableResource leasableResource, TimeSpan duration, dynamic ownerToken = null)
        {
            if (leasableResource == null)
            {
                throw new ArgumentNullException("leasableResource");
            }

            this.leasableResource = leasableResource;
            this.duration = duration;
            this.ownerToken = ownerToken;

            cancellationTokenSource.CancelAfter(Duration);
        }

        public LeasableResource LeasableResource
        {
            get
            {
                return leasableResource;
            }
        }

        public TimeSpan Duration
        {
            get
            {
                return duration;
            }
        }

        public dynamic OwnerToken
        {
            get
            {
                return ownerToken;
            }
        }

        public CancellationToken CancellationToken
        {
            get
            {
                return cancellationTokenSource.Token;
            }
        }

        public async Task Extend(TimeSpan by)
        {
            Console.WriteLine(string.Format("[Distribute] requesting extension: {0}: ", this) + duration);

            if (completed)
            {
                throw new InvalidOperationException("The lease cannot be extended.");
            }

            duration += by;
            cancellationTokenSource.CancelAfter(by);

            Console.WriteLine(string.Format("[Distribute] extended: {0}: ", this) + duration);
        }

        public override string ToString()
        {
            return LeasableResource.ToString();
        }

        internal void NotifyCompleted()
        {
            completed = true;
        }
    }
}
# gke-preemptible-high-availability
High-ish Availability Cluster for cheap

## Details

NodeLocal DNSCache

While intended to help reduce the latency of DNS queries, it can also serve as a bit of a stop-gap in the event that 
kube-dns goes away.

Info: https://cloud.google.com/kubernetes-engine/docs/how-to/nodelocal-dns-cache

Autoscaling profile

https://cloud.google.com/kubernetes-engine/docs/how-to/node-auto-provisioning

Optimize utilization - Scales down more aggressively. Not an issue as long as we set the min-nodes properly


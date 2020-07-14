# A Cheap Kubernetes Cluster for Node with Socket.io

As a disclaimer, I'm not claiming this is a perfect fit for everyone. Different applications have different technical 
requirements, and different uptime or availability standards. But I aim to outline the basics for an inexpensive GKE 
cluster with Node microservices in mind.

## Cluster Features

- preemptible nodes to reduce cost
- automatic SSL management with cert-manager and lets-encrypt
- ingress websocket stickiness

## Why a cluster at all? Why not just a VM?

If your only consideration is price at the cost of everything else, then it's probably cheaper to just use a VM. However, deploying into a cluster offers a number of advantages for not that much more money.

A GKE cluster gives you tons of stuff for free that you would otherwise have to do without or engineer yourself. 

- Dockerized applications ensure portable and reproducable builds
- Deployments are automatically health-checked as they roll out and stop if something is broken
- Failing instances are automatically taken off the load balancer and restarted
- Ingress controllers can automatically provision and update your SSL certs
- Resource management becomes much easier as individual applications can be limited by CPU or memory, and distributed optimally over machines
- New applications can be deployed with minimal complexity
- High availability becomes a matter of how much you want to pay rather than an engineering problem

In my mind the only real argument against any of this is just the cost of a cluster. But properly configured, a simple cluster can deployed for minimal cost. 

## High (ish) Availability

In this scenario I need my cluster to be able to perform deployments and node updates with no downtime as those two events are likely to be relatively frequent.

That said, I don't need and can't afford 100% uptime. I don't need multi-zone redundancy, and definitely not multi-cloud failover.

I can tolerate the risk of up to a minute or so of unexpected downtime once a month or so if it reduces my costs significantly. All of 
the microservices running [Asserted](https://asserted.io) are stateless and make heavy use of Cloud PubSub, so that even if a microservice is unavailable for a minute or two, most processes are not impacted.

## Preemptible Nodes

This is basically where all the cost savings comes from. A preemptible e2-small costs 30% of a standard VM. But comes with [some caveats](https://cloud.google.com/compute/docs/instances/preemptible#limitations):

- preemptible nodes can be killed at any time. Even within minutes of starting (though rare in my experience).
- Google claims they always restart instances within 24hrs, though I've found this to not be the case
- preemptible nodes may not always be available. This seems to be more of an issue for larger VMs, never seen this issue myself.

If your services are stateless, this should not be much of an issue. The only real problem happens if the lifetime of the Nodes is syncronized and 
Google decides to kill all of them at the same time. This risk can be minimized by running something like [preemptible-killer](https://github.com/estafette/estafette-gke-preemptible-killer), but I haven't found it necessary yet.

## Creating the Cluster

### Cluster Details

- zone
    - The first zonal cluster in a given billing account is free. A regional cluster would increase costs by about $72 USD a month
    - If you already have other clusters in your org, then I would probably opt for the regional cluster as the cost is the same.
- machine-type
    - Obviously subject to your requirements, but most Node microservices in my experience require at most 1 core and 512 MB per instance. Usually 250 MB is enough. 
    - In this case we're only going to have 3 API containers, so 3 e2-small's are enough for CPU and redundancy.
- disk-type and disk-size
    - A 10 GB SSD is inexpensive and fast. Usually the standard 100GB is more than what is needed for a standard Node app that isn't storing anything locally.
    - SSD vs standard persistent disk costs about $1.40 per month per node more, but speeds up deployments as the images can be downloaded faster
- preemptible, num_nodes=3
    - As mentioned above, preemptible saves the money. But we still want at least 3 nodes for redundancy
- addons HorizontalPodAutoscaling,HttpLoadBalancing,NodeLocalDNS
    - The extra option here is NodeLocalDNS. While intended to help reduce the latency of DNS queries, it can also serve as a bit of a stop-gap in the event that kube-dns is on a node that gets killed
    - [Details](https://cloud.google.com/kubernetes-engine/docs/how-to/nodelocal-dns-cache)
- autoscaling-profile optimize-utilization
    - This makes the node autoscaler more aggressive about killing extra nodes.
    - [Details](https://cloud.google.com/kubernetes-engine/docs/how-to/node-auto-provisioning)

The full command is below:

```bash
gcloud container --project $PROJECT_NAME clusters create $NEW_CLUSTER_NAME \ 
    --zone $CLUSTER_ZONE \
    --release-channel "regular" \
    --machine-type "e2-small" \
    --disk-type "pd-ssd" \
    --disk-size "10" \    
    --preemptible --num-nodes "3" \
    --enable-autoscaling --min-nodes "3" --max-nodes "9" \
    --addons HorizontalPodAutoscaling,HttpLoadBalancing,NodeLocalDNS \
    --enable-ip-alias \
    --enable-autoupgrade \
    --enable-autorepair \
    --max-surge-upgrade 1 \
    --max-unavailable-upgrade 0 \
    --autoscaling-profile optimize-utilization \
    --enable-shielded-nodes \
    --shielded-secure-boot
```

It will take a few minutes to complete.

## API Implementation

The example API is only a few lines, but has a fair bit going on.

```javascript
const express = require('express');
const http = require('http');
const socketio = require('socket.io');
const socketRedis = require('socket.io-redis');
const gracefulShutdown = require('http-graceful-shutdown');
const getenv = require('getenv');
const os = require('os');

const app = express();
const port = getenv('PORT');

const server = http.createServer(app);

// Serve static files for simple UI
app.use(express.static('public'));

// Health check endpoint
app.get('/health', (req, res) => res.send('Healthy'));

const io = socketio(server);

// Handling multiple nodes: https://socket.io/docs/using-multiple-nodes/ by using redis pubsub to broadcast events
io.adapter(socketRedis({ host: getenv('REDIS_HOST'), port: getenv('REDIS_PORT') }));

// Socket emit
io.on('connection', (socket) => socket.emit('hostname', os.hostname()));

// Start server
server.listen(port, () => console.log(`app listening at http://localhost:${port}`));

// Handle SIGINT or SIGTERM and drain connections
gracefulShutdown(server);
```

## Deploying Redis

Redis is only included as an in-cluster deployment for the purposes of this example. It's likely that in a production environment, if Redis is required, you likely wouldn't want it on a preemptible instance.

A better choice is to use a node selector or node affinity to deploy it onto a non-preemptible VM, or even just substitute with Redis Memorystore if the budget allows.

```bash
kubectl apply -f cluster/redis
```

## Deploying the API

### Namespace

Create the namespace first.

```bash
kubectl apply -f cluster/namespace.yml
```

### ConfigMap, Deployment, and Service

The configMap, deployment, and service are mostly pretty standard, but I'll highlight the important details.

The `deploy.yml` specifies pod anti-affinity to spread the API pods as widely as possible across the nodes.

```yaml
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchExpressions:
                - key: application
                  operator: In
                  values:
                    - api
                - key: component
                  operator: In
                  values:
                    - api
            topologyKey: kubernetes.io/hostname 
``` 

```bash
kubectl apply -f cluster/api/configMap.yml
kubectl apply -f cluster/api/deploy.yml
kubectl apply -f cluster/api/service.yml
```

## Creating the IP

Create a public external IP to bind to the ingress

```bash
gcloud compute addresses create test-api-ip --global
```

Configure your DNS provider to point to the IP.

## Create ingress and managed certificate

```bash
kubectl apply -f cluster/api/managedCert.yml
kubectl apply -f cluster/api/ingress.yml
```

It'll take up to 20 minutes to create the managed certificate. You can monitor the cert creation and the ingress creation with the following:

```bash
watch kubectl describe ManagedCertificate
watch kubectl get ingress
```

## 

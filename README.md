# Kubernetes Cluster for a NodeJS API with Socket.io and automatic SSL

As a disclaimer, I'm not claiming this is a perfect fit for everyone. Different applications have different technical 
requirements, and different uptime or availability standards. But I aim to outline the basics for an inexpensive GKE 
cluster with Node microservices in mind.

## Sponsor 

![asserted.io](https://raw.githubusercontent.com/ehacke/node-gke-cluster/master/images/logo.png)

[asserted.io - Test in Prod](https://asserted.io)

Here's a blog post on [the details of this and how to use it](https://asserted.io/posts/kubernetes-cluster-nodejs-api-with-socket-io-and-ssl)

## Cluster Features

- preemptible nodes to reduce cost (optional)
- automatic SSL management with cert-manager and lets-encrypt
- ingress websocket stickiness

## Creating the Cluster

### Cluster Details

The full command is below:

```bash
gcloud container --project $PROJECT_NAME clusters create $NEW_CLUSTER_NAME \
    --zone $CLUSTER_ZONE \    
    # Zone
    # - First zonal cluster in a billing account is free. A regional cluster would increase costs by about 
    #   $72 USD a month
    # - If you already have other clusters in your org, then I would probably opt for the regional cluster as 
    #   the cost is the same. 
    --machine-type "e2-small" \
    # Machine Type
    # - Obviously subject to your requirements, but most Node microservices in my experience require at most 1 
    #   core and 512 MB per instance. Usually 250 MB is enough. 
    # - In this case we're only going to have 3 API containers, so 3 e2-small's are enough for CPU and redundancy.
    --disk-type "pd-ssd" \
    --disk-size "10" \    
    # Disk type and size
    # - A 10 GB SSD is inexpensive and fast. Usually the standard 100GB is more than what is needed for a standard 
    #   Node app that isn't storing anything locally.
    # - SSD vs standard persistent disk costs about $1.40 per month per node more, but speeds up deployments as 
    #   the images can be downloaded faster
    --preemptible --num-nodes "3" \
    # Preemeptible nodes
    # - As mentioned, don't use preemptible unless you can tolerate the occasional 1-2 minute blip.
    # - Preemptible saves the money. But we still want at least 3 nodes for redundancy.
    --addons HorizontalPodAutoscaling,HttpLoadBalancing,NodeLocalDNS \
    # NodeLocalDNS
    # - The extra option here is NodeLocalDNS. While intended to help reduce the latency of DNS queries, it can also 
    #   serve as a bit of a stop-gap in the event that kube-dns is on a node that disappears 
    #   https://cloud.google.com/kubernetes-engine/docs/how-to/nodelocal-dns-cache
    --autoscaling-profile optimize-utilization \
    # Optimize Utilization
    # - This makes the node autoscaler more aggressive about killing extra nodes. 
    #   https://cloud.google.com/kubernetes-engine/docs/how-to/node-auto-provisioning
    --enable-autoscaling --min-nodes "3" --max-nodes "9" \
    --release-channel "regular" \
    --enable-ip-alias \
    --enable-autoupgrade \
    --enable-autorepair \
    --max-surge-upgrade 1 \
    --max-unavailable-upgrade 0 \
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
const port = getenv.int('PORT');

const server = http.createServer(app);

// Serve static files for simple UI
app.use(express.static('public'));

// Not really necessary for this example, but this ensures the request IP matches the client and not the load-balancer
app.enable('trust proxy');

// Health check endpoint
app.get('/health', (req, res) => res.send('Healthy'));

const io = socketio(server);

// Handling multiple nodes: https://socket.io/docs/using-multiple-nodes/
io.adapter(socketRedis({ host: getenv('REDIS_HOST'), port: getenv('REDIS_PORT') }));

// Socket emit
io.on('connection', (socket) => socket.emit('hostname', os.hostname()));

// Start server
server.listen(port, () => console.log(`app listening at http://localhost:${port}`));

// Handle SIGINT or SIGTERM and drain connections
gracefulShutdown(server);
```

### Deploy

Once the cluster is up, run the following:

```bash
kubectl apply -f cluster/namespace.yml
kubectl apply -f cluster/redis

## Wait for redis to come up
 
kubectl apply -f cluster/api
``` 

## Success!

Once everything is up, you should be able to navigate to the URL you bound to the external IP, and see the connected hostname sent over Socket.io.

As you refresh, the connected hostname should not change which indicates that socket.io and the session affinity are working.

You now have all the basic configuration you need for a Kubernetes cluster with automatic SSL and websocket/socket.io support!

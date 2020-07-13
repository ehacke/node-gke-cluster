#!/usr/bin/env bash

gcloud beta container --project "asserted-dev" clusters create "dev-cluster" \
    --zone "us-central1-c" \
    --release-channel "regular" \
    --machine-type "e2-small" \
    --image-type "COS" \
    --disk-type "pd-ssd" \
    --disk-size "10" \
    --enable-ip-alias \
    --preemptible --num-nodes "3" \
    --enable-autoscaling --min-nodes "3" --max-nodes "9" \
    --addons HorizontalPodAutoscaling,HttpLoadBalancing,NodeLocalDNS \
    --enable-autoupgrade \
    --enable-autorepair \
    --max-surge-upgrade 1 \
    --max-unavailable-upgrade 0 \
    --autoscaling-profile optimize-utilization \
    --enable-shielded-nodes \
    --shielded-secure-boot

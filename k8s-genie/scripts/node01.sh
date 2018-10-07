#!/bin/bash

set -ex

# Wait for docker, else network might not be ready yet
while [[ `systemctl status docker | grep active | wc -l` -eq 0 ]]
do
    sleep 2
done

kubeadm init --config /etc/kubernetes/kubeadm.conf

kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f /etc/kubernetes/genie.yml
kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f /etc/kubernetes/flannel.yml
kubectl --kubeconfig=/etc/kubernetes/admin.conf taint nodes node01 node-role.kubernetes.io/master:NoSchedule-

# set ptp cni static configuration
mkdir -p /etc/cni/net.d/
cp /tmp/static-ptp-conf.yaml /etc/cni/net.d/10-ptp.conf

# update the genie configuration to use flannel as default cni lugin
kubectl --kubeconfig=/etc/kubernetes/admin.conf replace -f /tmp/genie-configmap.yaml

# Wait for api server to be up.
kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes --no-headers
kubectl_rc=$?
retry_counter=0
while [[ $retry_counter -lt 20 && $kubectl_rc -ne 0 ]]; do
    sleep 10
    echo "Waiting for api server to be available..."
    kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes --no-headers
    kubectl_rc=$?
    retry_counter=$((retry_counter + 1))
done
kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f /tmp/local-volume.yaml
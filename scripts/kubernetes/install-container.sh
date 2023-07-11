#!/bin/bash
repo=registry.aliyuncs.com/google_containers

for name in `kubeadm config images list --kubernetes-version v1.27.3`; do

    src_name=${name#k8s.gcr.io/}
    src_name=${src_name#coredns/}

    docker pull $repo/$src_name

    docker tag $repo/$src_name $name
    docker rmi $repo/$src_name
done

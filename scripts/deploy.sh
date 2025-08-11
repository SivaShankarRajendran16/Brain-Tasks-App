#!/bin/bash
set -e

echo "Updating kubeconfig for EKS..."
aws eks update-kubeconfig --region ap-south-1 --name brain-cluster

echo "Deploying application to EKS..."
kubectl apply -f /tmp/k8s/deployment.yaml

echo "Checking rollout status..."
kubectl rollout status deployment/brain-tasks-deployment

echo "Deployment completed successfully."

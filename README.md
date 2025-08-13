# Brain Tasks – CI/CD to Amazon EKS with CodePipeline

This document explains, step by step, how the **Brain Tasks** React application is built, containerized, and deployed to **Amazon EKS** using **AWS CodePipeline** and **AWS CodeBuild**, with images pushed to **Amazon ECR**.


## High-Level Architecture

```
GitHub (main)
     │  (webhook/connection)
     ▼
AWS CodePipeline ──► Source (GitHub)
     │
     ├─► Build (CodeBuild)
     │      • docker build
     │      • docker push to Amazon ECR
     │      • outputs manifest/artifact for deploy
     │
     └─► Deploy (Amazon EKS)
            • kubectl apply -f service-deployment.yml
            • Service type: LoadBalancer  ──►  AWS NLB/ALB (Public URL)

## Step 1 — Create Amazon ECR Repository

1. Open **Amazon ECR** → **Create repository** (e.g., `brain-tasks`).
2. Note the repository URI (e.g., `ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/brain-tasks`).

**Permissions**: Ensure the build role can `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:CompleteLayerUpload`, `ecr:GetDownloadUrlForLayer`, `ecr:InitiateLayerUpload`, `ecr:PutImage`, `ecr:UploadLayerPart`.

---

## Step 2 — Add `buildspec.yml` to the Repo

A typical `buildspec.yml` to build and push a Docker image to ECR and pass Kubernetes manifests to the next stage looks like this (adjust names/paths as needed):

```yaml
version: 0.2

env:
  variables:
    IMAGE_TAG: "latest"
  parameter-store:
    # Optional: if you store secrets in SSM
    # GITHUB_TOKEN: "/my/param/name"

phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws --version
      - ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
      - REGION=ap-south-1
      - REPO_NAME=brain-tasks
      - ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME"
      - aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI
  build:
    commands:
      - echo Building the Docker image...
      - docker build -t $REPO_NAME:$IMAGE_TAG .
      - docker tag $REPO_NAME:$IMAGE_TAG $ECR_URI:$IMAGE_TAG
  post_build:
    commands:
      - echo Pushing the Docker image...
      - docker push $ECR_URI:$IMAGE_TAG
      - echo Writing image definition file...



## Step 3 — Create/Configure AWS CodeBuild Project

- **Environment**: Managed image with Docker (privileged mode enabled).
- **Service Role**: Allow ECR push/pull and SSM (if used).
- **Buildspec**: Use `buildspec.yml` from the repository root.
- **Environment variables** (examples):
  - `IMAGE_TAG=latest` (or use the commit SHA).
- Confirm builds succeed; check **CloudWatch Logs** for build output.


**CloudWatch – CodeBuild build succeeded**

## Step 4 — Create/Validate the EKS Cluster

You can create with `eksctl`, console, or CLI. Example with CLI to update kubeconfig from a bastion/EC2:

```bash
aws eks --region ap-south-1 update-kubeconfig --name brain-cluster
kubectl get nodes
```

Grant the **CodePipeline service role** access to the cluster by mapping the IAM role in the `aws-auth` ConfigMap (from an admin workstation):

```bash
kubectl edit configmap aws-auth -n kube-system
# add something like:
#  mapRoles:
#    - rolearn: arn:aws:iam::<ACCOUNT_ID>:role/AWSCodePipelineServiceRole-<suffix>
#      username: codepipeline
#      groups:
#        - system:masters


**kubectl – pods running and Service with external LoadBalancer**
```
## Step 5 — Create AWS CodePipeline

1. **Creation Option**: *Build custom pipeline*.

**CodePipeline – choose creation option**

![CodePipeline – choose creation option](<screenshots/Screenshot (429).png>)


2. **Pipeline Settings**:
   - Name: `brain`
   - Execution mode: `Queued`
   - Service role: existing service role (or create new).

**Pipeline settings**

![Pipeline settings](<screenshots/Screenshot (430).png>)


3. **Source Stage**:
   - Provider: **GitHub** (via GitHub App is recommended).
   - Repository: `SivaShankarRajendran16/Brain-Tasks-App`
   - Branch: `main`

**Add source stage**

![Add source stage](<screenshots/Screenshot (431).png>)


4. **Build Stage**:
   - Build provider: **AWS CodeBuild**
   - Project: `brain`

**Add build stage**

![Add build stage](<screenshots/Screenshot (432).png>)


5. **Deploy Stage (Amazon EKS)**:
   - Region: `ap-south-1 (Mumbai)`
   - Cluster: `brain-cluster` (your cluster name)
   - Namespace: `default` (or your namespace)
   - Manifest file: `service-deployment.yml`
   - Input artifacts: `SourceArtifact` (or from build as appropriate)

**Add deploy stage – Amazon EKS**

![Add deploy stage – Amazon EKS](<screenshots/Screenshot (433).png>)


> The deploy action uses the cluster connection + the IAM role you provided to apply the manifest with `kubectl` under the hood.

---

## Step 6 — Kubernetes Manifests

An example `service-deployment.yml` for a simple web app (update image URI to match ECR):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mind-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: mind
  template:
    metadata:
      labels:
        app: mind
    spec:
      containers:
        - name: mind
          image: <ACCOUNT_ID>.dkr.ecr.ap-south-1.amazonaws.com/brain-tasks:latest
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: mind-task-service
spec:
  type: LoadBalancer
  selector:
    app: mind
  ports:
    - port: 80
      targetPort: 80
```

## Step 7 — Validate the Application

- Wait for the **EXTERNAL-IP** to be provisioned on the LoadBalancer service.
- Test the URL in a browser:

**Public URL**: http://abfaa271bd4aa4084a7876fda76d834a-808226274.ap-south-1.elb.amazonaws.com


##step 8 : cloudwatch
finally go to aws cloudwatch console and check the events or logs 


## Troubleshooting

- **Source**: Check CodePipeline execution details.
- **Build**: Open CodeBuild run → **CloudWatch Logs**. Verify ECR login, image build and push.
- **Deploy**: Ensure the CodePipeline role is mapped in `aws-auth`. Run:
  ```bash
  kubectl describe deploy mind-deployment
  kubectl describe svc mind-task-service
  ```
- **Image not pulled**: Verify the image URI and tag in the manifest match ECR.
- **LoadBalancer pending**: Confirm subnets are public and cluster has IAM roles for service controllers.

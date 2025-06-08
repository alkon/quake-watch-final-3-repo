### ArgoCD and GitHub Container Registry (GHCR) Integration
- Core concepts:
  - ArgoCD Application `k8s/argocd-app.yaml` - defines what to deploy and from where
  - ArgoCD Repository Secret `k8s/argocd-repo-secret` - authenticates ArgoCD itself to pull Helm charts from private OCI registries (like GHCR). This secret should NOT be committed to Git with sensitive data
  - Kubernetes Image Pull Secret `K8s/ghcr-image-pull-secret` - authenticates Kubernetes nodes (kubelet) to pull Docker images from registries (like GHCR). This secret should NOT be committed to Git with sensitive data.
  - Note 1: Sensitive data moved to imperative commands to enable git push for secrets
  ```text
     kubectl create secret generic argocd-repo-ghcr-alkon \
    --namespace argocd \
    --from-literal=url='ghcr.io/alkon' \
    --from-literal=type='helm' \
    --from-literal=name='ghcr-alkon-repo-name' \
    --from-literal=enableOCI='true' \
    --from-literal=username='alkon' \
    --from-literal=password='<YOUR_YOUR_GITHUB_PAT>' \
    --dry-run=client -o yaml | kubectl apply -f - 
  ```
  ```text
     # Generate the raw JSON  content
     RAW_DOCKER_CONFIG_JSON='{"auths":{"ghcr.io":{"auth":"'$(echo -n "alkon:<YOUR_GITHUB_PAT>" | base64 | tr -d '\n')'"}}}'
     echo "Generated raw Docker config JSON. Now use it in the next command."
  
     # Then create the secret
     echo "$RAW_DOCKER_CONFIG_JSON" | kubectl create secret generic ghcr-image-pull-secret \
    --namespace default \
    --type=kubernetes.io/dockerconfigjson \
    --from-file=.dockerconfigjson=/dev/stdin
  ``` 
  - Note 2: Helm Chart values.yaml Modification
    ```text
    imagePullSecrets: 
      - name: ghcr-image-pull-secret # <-- Refers to Kubernetes Image Pull Secret
   ```


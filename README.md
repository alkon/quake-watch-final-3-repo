## The Quake Watch Final Project - Phase 3

This project demonstrates a robust CI/CD pipeline for a Python application and its Kubernetes deployment, leveraging GitHub Actions, Helm, ArgoCD, and n8n for automated testing.

### 1. Package Management with Helm

Helm is used to package the Kubernetes application, making it easily deployable and manageable.

**a) Helm Chart Creation (`k8s/quake-watch-app-chart`):**

The Helm chart for the Quake Watch application is located in `k8s/quake-watch-app-chart`. This directory contains the following key files:

* **`Chart.yaml`**: Defines the metadata for the Helm chart, including its name, version, and application version. This file is crucial for identifying and managing the chart.
* **`values.yaml`**: Provides default configuration values for the chart. These values can be overridden during deployment, allowing for flexible configurations across different environments.
* **`templates/`**: Contains the Kubernetes manifest templates (e.g., `deployment.yaml`, `service.yaml`) that define the resources required for the application. Helm's templating engine allows for dynamic generation of these manifests based on `values.yaml` and other inputs.
* **`.helmignore`**: Specifies files and directories that should be ignored when packaging the Helm chart.

**b) Publishing the Helm Chart to an Artifact Repository:**

The CI/CD pipeline automates the publication of the Helm chart to the GitHub Container Registry (GHCR), which acts as an OCI-compliant artifact repository.

* **`build-and-publish` job (in `publish-and-deploy.yaml`):**
    * Logs into GHCR using `docker/login-action`.
    * Uses a custom action `./.github/actions/extract-chart-metadata` to extract essential metadata (name, version, app version) from `Chart.yaml`. This ensures that the published artifacts are correctly tagged and versioned.
    * The `helm package` command is used to create a `.tgz` archive of the Helm chart.
    * The `helm push` command then pushes this packaged chart to the specified GHCR OCI repository (e.g., `oci://ghcr.io/your-github-username`).

### 2. Version Control with Git

Git is used for source code management, with a clear branching strategy to facilitate parallel development and maintain stability.

**Branches Used:**

* **`main`**: The primary branch, representing the stable and production-ready state of the application and infrastructure. All deployments to production environments originate from this branch.
* **`feature/app`**: Used for developing new features or making significant changes to the Python application code.
* **`feature/k8s`**: Dedicated to changes related to Kubernetes configurations, Helm chart updates, or other infrastructure-as-code modifications.
* **`feature/workflows`**: Used for developing and testing changes to the GitHub Actions CI/CD workflows themselves.

### 3. CI/CD Pipeline with GitHub Actions

GitHub Actions is the backbone of the CI/CD pipeline, automating the build, test, and deployment processes.

**a) GitHub Actions for CI/CD:**

The main workflow definition is in `publish-and-deploy.yaml`. It is triggered on pushes to the `main` branch and also allows for manual `workflow_dispatch` to enable re-runs or specific deployments.

**b) Different Stages in the Pipeline:**

The pipeline is structured into distinct stages, each with a specific responsibility:

* **`lint` (Test Stage):**
    * **Purpose:** Ensures code quality and adherence to coding standards for the Python application.
    * **Implementation:** Uses a reusable workflow `./.github/workflows/reusable-python-task.yaml`.
    * **Details:** Runs `pylint` on `app/app.py` with a `--fail-under=7.0` threshold.
    * **Matrix Build:** This stage utilizes a matrix strategy to run linting against multiple Python versions (`3.12`, `3.13`), ensuring compatibility and catching version-specific issues.

* **`build-and-publish` (Build Stage):**
    * **Purpose:** Builds the Docker image for the Python application and publishes both the Docker image and the Helm chart to GHCR.
    * **Dependencies:** Requires the `lint` job to pass.
    * **Implementation:**
        * Checks out the code.
        * Logs into GHCR.
        * Extracst chart metadata using a custom action.
        * Builds and pushes the Docker image using `docker/build-push-action`, tagging it with the `app_version` extracted from `Chart.yaml`.
        * Packages the Helm chart and pushes it to GHCR as an OCI artifact.

* **`deploy` (Deployment Stage):**
    * **Purpose:** Deploys the application to a Kubernetes cluster using ArgoCD.
    * **Dependencies:** Requires the `build-and-publish` job to complete successfully.
    * **Implementation:**
        * Checks out the code.
        * Sets up Kubeconfig for a K3D cluster using a custom action `./.github/actions/setup-kubeconfig`.
        * Retrieves the ArgoCD admin password from a Kubernetes secret.
        * Logs into ArgoCD.
        * Updates the target revision of the ArgoCD application (e.g., `quake-watch-app`) to the newly published Helm chart version.
        * Triggers an ArgoCD application sync to pull the latest chart and deploy the application.
        * Waits for the ArgoCD application to be healthy and synced.

**c) Matrix Builds for `lint`:**

The `lint` job demonstrates the use of matrix builds. The `strategy.matrix.python-version` configuration allows the job to run in parallel for Python versions "3.12" and "3.13", ensuring that the application adheres to linting rules across different Python environments.

### 4. n8n Usage for End-to-End Testing

n8n is integrated into the CI/CD pipeline for automated end-to-end (E2E) testing of the deployed application.

* **`call-e2e-test` job (in `publish-and-deploy.yaml`):**
    * **Dependencies:** Requires both `deploy` and `build-and-publish` to complete.
    * **Implementation:**
        * Uses a reusable workflow `./.github/workflows/test-app-with-n8n.yaml`.
        * Passes necessary inputs like the Docker image tag, application name for port forwarding, and internal/local ports.
        * Crucially, it passes the `KUBECONFIG` and `N8N_WEBHOOK_URL` as secrets.
        * This reusable workflow likely orchestrates the following:
            * Setting up port forwarding to expose the deployed application locally.
            * Triggering an n8n workflow via a webhook URL (`N8N_TEST_WEBHOOK_URL`).
            * The n8n workflow then executes a series of tests against the exposed application (e.g., API calls, UI interactions) and reports the results back to the GitHub Actions workflow, indicating success or failure. This allows for comprehensive testing of the live application after deployment.

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
 

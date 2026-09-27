Helm — Lesson 5
Complete Guide: From Scratch to Production
Enterprise Order Platform • Kubernetes • AKS • Azure DevOps

This document is intentionally written as a reusable reference.
# 1. Why This Document Exists
This is the complete Lesson 5 reference for Helm. It starts from the basic question “What is Helm?” and progresses through charts, values, templates, releases, ConfigMaps, Secrets, commands, troubleshooting, and production usage. The examples are tied to the enterprise-order-platform project so that the concepts remain practical.
Learning rule: understand the problem Helm solves first, then learn the commands. Do not memorize commands without understanding what Helm is doing.
# 2. What Is Helm?
Helm is a package manager and templating/deployment tool for Kubernetes. It lets you package a set of Kubernetes manifests into a reusable Chart and deploy that Chart as a Release. Instead of maintaining many nearly identical YAML files for each environment, you keep templates plus configurable values.
Without Helm:
Kubernetes YAML files
↓
kubectl apply -f ...
↓
Kubernetes

With Helm:
Chart + values
↓
Helm template engine
↓
Kubernetes manifests
↓
Helm Release
↓
Kubernetes
# 3. Why Do We Need Helm?
Imagine your order-service has these Kubernetes resources:
- Deployment
- Service
- ConfigMap
- Secret
- Istio Gateway
- Istio VirtualService
- PeerAuthentication
  Now imagine three environments: dev, staging, and production. Without Helm, you can easily end up copying and editing the same YAML repeatedly.
## 3.1 What happens without Helm?
k8s/
├── dev/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   └── ...
├── staging/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   └── ...
└── prod/
├── deployment.yaml
├── service.yaml
├── configmap.yaml
└── ...
- YAML duplication increases.
- A change must be repeated in multiple files.
- One environment can accidentally drift from another.
- Image tags, replicas, resource limits, URLs and feature flags are easy to change inconsistently.
- Rollback becomes more manual.
- CI/CD pipelines have more YAML files and environment-specific logic.
- Reusable deployment patterns are harder to maintain.
## 3.2 With Helm
helm/
└── order-service/
├── Chart.yaml
├── values.yaml
├── values-dev.yaml
├── values-prod.yaml
└── templates/
├── deployment.yaml
├── service.yaml
├── configmap.yaml
├── gateway.yaml
├── virtualservice.yaml
└── ...
The same templates can be reused. Only environment-specific values change.
# 4. Helm in One Simple Example
Suppose the Deployment contains:
image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
replicas: {{ .Values.replicaCount }}
values.yaml:
replicaCount: 1

image:
repository: order-service
tag: "0.1.5"
Helm renders:
image: "order-service:0.1.5"
replicas: 1
If dev values say tag 0.1.6 and replicas 2, the same template can render:
image: "order-service:0.1.6"
replicas: 2
This is the central idea of Helm: templates define structure; values control configuration.
# 5. Important Helm Terminology
# 6. Helm Architecture / Mental Model
Developer
│
│ helm install / upgrade
▼
Helm CLI
│
├── Chart.yaml
├── values.yaml
├── environment values
└── templates/
│
▼
Helm rendering engine
│
▼
Rendered Kubernetes manifests
│
▼
Kubernetes API Server
│
├── Deployment
├── Service
├── ConfigMap
├── Secret
└── other resources
│
▼
Pods / Services / Istio resources
Important: Helm is not a replacement for Kubernetes. Helm uses the Kubernetes API to install and manage Kubernetes resources.
# 7. Our Chart Structure
helm/order-service/
├── Chart.yaml
├── values.yaml
├── values-dev.yaml
└── templates/
├── deployment.yaml
├── service.yaml
├── configmap.yaml
├── gateway.yaml
├── virtualservice.yaml
└── peerauthentication.yaml
## 7.1 Chart.yaml
apiVersion: v2
name: order-service
description: Helm chart for the Enterprise Order Service
type: application
version: 0.1.0
appVersion: "0.1.5"
version is the Chart version. appVersion describes the application version. They serve different purposes.
# 8. values.yaml — Default Configuration
replicaCount: 1

image:
repository: order-service
tag: "0.1.5"
pullPolicy: IfNotPresent

database:
url: jdbc:postgresql://host.docker.internal:5432/orderdb

service:
type: ClusterIP
port: 8080

resources:
requests:
cpu: 100m
memory: 256Mi
limits:
cpu: 500m
memory: 512Mi
values.yaml should provide sensible defaults. Environment files override only what needs to change.
# 9. values-dev.yaml — Environment Override
replicaCount: 1

image:
tag: "0.1.6"

database:
url: jdbc:postgresql://host.docker.internal:5432/orderdb

app:
environment: dev
orderTimeoutSeconds: 30
This file is not automatically used merely because its name contains “dev”. You must explicitly provide it:
helm upgrade order-dev helm/order-service `
  -n order-dev `
-f helm/order-service/values-dev.yaml
# 10. Values Precedence
For the practical workflow in this project, think of the effective values as being built from defaults and then overridden by more specific inputs.
values.yaml
↓ overridden by
-f values-dev.yaml
↓ overridden by
--set
↓
final values used for this command
Example:
values.yaml:
image.tag: 0.1.5

values-dev.yaml:
image.tag: 0.1.6

command:
--set image.tag=0.1.7

effective value:
image.tag = 0.1.7
Use `helm get values ... --all` when you need to understand the values associated with a release.
# 11. Helm Templates
Helm templates use Go-template syntax. Example from our Deployment:
image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"

env:
- name: SPRING_DATASOURCE_URL
  value: {{ .Values.database.url | quote }}
  `.Values` refers to the values available to the chart. The pipe `|` sends a value through a template function.
## 11.1 Important template constructs
- `{{ .Values.x }}` — read a value.
- `if` / `else` — conditionally render YAML.
- `with` — change the current context.
- `range` — loop over lists/maps.
- `default` — provide a fallback.
- `required` — fail rendering if an important value is missing.
- `quote` — safely quote strings.
- `toYaml` — turn structured values into YAML.
- `nindent` — indent generated YAML.
  {{ default "INFO" .Values.app.logLevel }}

{{ required "database.url is required" .Values.database.url }}

{{ .Values.database.url | quote }}

resources:
{{- toYaml .Values.resources | nindent 12 }}
# 12. ConfigMap
ConfigMap is for non-sensitive configuration.
apiVersion: v1
kind: ConfigMap
metadata:
name: order-service-config
data:
APP_ENVIRONMENT: "dev"
ORDER_TIMEOUT_SECONDS: "30"
Our Deployment imports it:
envFrom:
- configMapRef:
  name: order-service-config
  The resulting environment variables are visible to the application container.
# 13. Kubernetes Secret + Helm
Secret is intended for sensitive configuration. For this lesson, use fake credentials only. Do not commit real production credentials to Git.
apiVersion: v1
kind: Secret
metadata:
name: order-db-secret
type: Opaque
stringData:
SPRING_DATASOURCE_USERNAME: {{ .Values.database.username | quote }}
SPRING_DATASOURCE_PASSWORD: {{ .Values.database.password | quote }}
The Deployment can consume one key:
- name: SPRING_DATASOURCE_PASSWORD
  valueFrom:
  secretKeyRef:
  name: order-db-secret
  key: SPRING_DATASOURCE_PASSWORD
  Important security point: Kubernetes Secret data is not automatically “encrypted because it is a Secret”. Base64 representation is encoding, not encryption. Production protection also involves encryption at rest, RBAC, cluster configuration, and preferably a dedicated secret-management system such as Azure Key Vault.
# 14. Helm Command Reference — Complete Practical Guide
The following commands are the commands you should know for interviews and real project work. They are grouped by purpose.
# 15. The Most Important Commands — Detailed
## 15.1 helm template
This is one of the most important debugging commands because it lets you inspect what Helm will generate before changing the cluster.
helm template order-dev helm/order-service `
  -n order-dev `
-f helm/order-service/values-dev.yaml
Useful pattern:
helm template order-dev helm/order-service `
  -n order-dev `
-f helm/order-service/values-dev.yaml |
Select-String -Pattern "image:|SPRING_DATASOURCE_URL|ConfigMap|Secret"
If the rendered YAML is wrong, do not deploy yet. Fix the Chart or values first.
## 15.2 helm lint
helm lint helm/order-service
This checks the Chart for common structural and template issues. It is a fast CI/CD quality gate.
## 15.3 helm install
helm install order-dev helm/order-service `
  -n order-dev `
--create-namespace `
-f helm/order-service/values-dev.yaml
Use when the Release does not already exist.
## 15.4 helm upgrade
helm upgrade order-dev helm/order-service `
  -n order-dev `
-f helm/order-service/values-dev.yaml
Use when the Release already exists.
## 15.5 helm upgrade --install
helm upgrade --install order-dev helm/order-service `
  -n order-dev `
-f helm/order-service/values-dev.yaml
This is extremely useful in CI/CD because the same command handles both first deployment and later deployments.
## 15.6 helm status
helm status order-dev -n order-dev
Use after deployment to confirm whether Helm considers the Release deployed and to see related resources.
## 15.7 helm history and rollback
helm history order-dev -n order-dev

helm rollback order-dev 8 -n order-dev
Every upgrade creates a new Release revision. A rollback creates a new revision that restores the selected previous state; it does not erase the history.
## 15.8 helm get values
helm get values order-dev -n order-dev
helm get values order-dev -n order-dev --all
helm get values order-dev -n order-dev --revision 8
The `--all` form includes computed values, including defaults merged with supplied overrides. This is useful when debugging why a rendered resource has a particular value.
## 15.9 helm get manifest
helm get manifest order-dev -n order-dev
This shows the manifests Helm stored for the Release. Compare this with the live Kubernetes resource when investigating drift.
# 16. The Helm Workflow You Should Memorize
1. Edit Chart / values
   ↓
2. helm lint
   ↓
3. helm template
   ↓
4. Review rendered YAML
   ↓
5. helm upgrade --install
   ↓
6. helm status
   ↓
7. kubectl get pods
   ↓
8. kubectl describe / logs if needed
   ↓
9. helm history
   ↓
10. helm rollback if required
    This is a much safer workflow than immediately running helm upgrade after every edit.
# 17. Our Real Helm Problem: kubectl vs Helm Ownership
During this lesson we encountered a real field-management conflict when Helm attempted to change the Deployment image while `kubectl-client-side-apply` also owned that field.
conflict with "kubectl-client-side-apply":
.spec.template.spec.containers[name="order-service"].image
The important lesson is architectural: avoid having multiple deployment mechanisms independently manage the same fields. In a production workflow, choose a clear owner such as Helm/CI-CD for application Deployment configuration.
Commands that helped us investigate:
kubectl get deployment order-service -n order-dev `
-o jsonpath="{.metadata.managedFields[*].manager}"

helm history order-dev -n order-dev
helm status order-dev -n order-dev
helm template order-dev helm/order-service -n order-dev -f helm/order-service/values-dev.yaml
We eventually aligned the deployment with the Helm chart and values and successfully reached a deployed Release.
# 18. Helm vs kubectl
# 19. Helm in Your Future Azure Architecture
Developer
↓
Git repository
↓
Azure DevOps Pipeline
├── build Spring Boot
├── run tests
├── build Docker image
├── push image to ACR
└── Helm upgrade --install
↓
AKS
↓
Helm Chart
↓
Deployment + Service + ConfigMap + Istio resources
↓
Pods
↓
Istio sidecars
For secrets, the production architecture can add Azure Key Vault and an appropriate integration mechanism rather than storing real credentials in Git-tracked Helm values.
# 20. What If We Do Not Use Helm in Our Project?
The project can absolutely run without Helm. Kubernetes does not require Helm. You could maintain raw manifests and deploy with kubectl. Helm becomes valuable as the number of resources, environments, configuration combinations, and deployment revisions grows.
Without Helm:
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f configmap.yaml
kubectl apply -f gateway.yaml
...

With Helm:
helm upgrade --install order-dev ./helm/order-service -f values-dev.yaml
The choice is therefore not “Kubernetes requires Helm”; the choice is whether Helm's packaging, templating, release management, reuse and rollback capabilities are useful for the application.
# 21. Production Rules to Remember
- Keep templates reusable; keep environment-specific differences in values.
- Use helm lint and helm template before deployment.
- Use one clear deployment owner for a resource/field set.
- Do not store real secrets in Git-tracked values files.
- Use resource requests and limits deliberately.
- Use image tags that identify immutable builds rather than relying on latest.
- Keep Release history so rollback remains possible.
- Use CI/CD to make deployments repeatable.
- Keep development conveniences such as host.docker.internal out of the future AKS production configuration.
- Use Azure Key Vault or another appropriate secret-management mechanism for production secrets.
# 22. Hands-On Practice Checklist
1. Run `helm lint helm/order-service`.
1. Run `helm template` using values-dev.yaml.
1. Find the rendered image tag.
1. Find the rendered SPRING_DATASOURCE_URL.
1. Find the rendered ConfigMap.
1. Run `helm upgrade --install`.
1. Check `helm status`.
1. Check `helm history`.
1. Run `helm get values --all`.
1. Run `helm get manifest`.
1. Change a dev value and observe the rendered result.
1. Rollback to a previous revision in the lab.
1. Explain ConfigMap vs Secret without looking at the notes.
1. Explain why values-dev.yaml is not automatically loaded.
1. Explain why Helm is useful even though kubectl can deploy YAML.
# 23. Interview Questions
1. What is Helm and why is it used with Kubernetes?
   Answer: ______________________________________________________________
2. What is the difference between a Chart and a Release?
   Answer: ______________________________________________________________
3. What problem does values.yaml solve?
   Answer: ______________________________________________________________
4. How do values-dev.yaml and --set affect values?
   Answer: ______________________________________________________________
5. What does helm template do?
   Answer: ______________________________________________________________
6. Difference between helm install and helm upgrade?
   Answer: ______________________________________________________________
7. When would you use helm upgrade --install?
   Answer: ______________________________________________________________
8. How does Helm rollback work?
   Answer: ______________________________________________________________
9. What is a ConfigMap?
   Answer: ______________________________________________________________
10. What is a Kubernetes Secret?
    Answer: ______________________________________________________________
11. Is a Kubernetes Secret encrypted by default simply because it is a Secret?
    Answer: ______________________________________________________________
12. How would you troubleshoot a Helm deployment that creates an unhealthy Pod?
    Answer: ______________________________________________________________
13. Why should helm template be run before deployment?
    Answer: ______________________________________________________________
14. What can cause Helm/Kubectl field-management conflicts?
    Answer: ______________________________________________________________
15. How would you integrate Helm into an Azure DevOps pipeline?
    Answer: ______________________________________________________________
16. How would you manage production secrets with Azure Key Vault?
    Answer: ______________________________________________________________
# 24. Lesson 5 Completion Criteria
- I can explain Helm to another developer in simple language.
- I understand why Helm is useful and what happens without it.
- I can explain Chart, Release, Values and Templates.
- I can create and inspect a Chart.
- I understand values.yaml and environment-specific values.
- I can use helm lint and helm template before deployment.
- I can install and upgrade a Release.
- I can inspect Release history and roll back.
- I understand ConfigMap and Secret.
- I understand the basic production secret-management direction.
- I can troubleshoot a Helm deployment systematically.
- I understand how Helm will fit into my future AKS + Azure DevOps architecture.
# 25. One-Page Memory Sheet
HELM = Kubernetes package manager + templating + release management

Chart     = package/template
Release   = deployed instance of a Chart
Values    = configuration
Template  = parameterized Kubernetes YAML

CORE FLOW:
values.yaml
+ values-dev.yaml
+ --set
  ↓
  Helm render
  ↓
  Kubernetes YAML
  ↓
  Kubernetes API
  ↓
  Resources / Pods

MUST-KNOW COMMANDS:
helm lint
helm template
helm install
helm upgrade
helm upgrade --install
helm status
helm list
helm history
helm rollback
helm uninstall
helm get values
helm get manifest
helm get all
helm show values
helm repo add
helm repo update
helm search repo
helm package
helm dependency update
helm test

SAFE WORKFLOW:
lint → template → deploy → status → verify → history/rollback

CONFIG:
ConfigMap = non-sensitive
Secret    = sensitive
Production secrets → dedicated secret management such as Azure Key Vault
# 26. Next Lesson
After this complete foundation, the next practical lesson should focus on Helm Secrets hands-on, then template functions, conditionals, reusable helpers, and finally production-grade chart patterns. We will continue using the enterprise-order-platform rather than switching to an unrelated example.

| Term | Meaning | In our project |
| --- | --- | --- |
| Chart | A packaged collection of Kubernetes templates and metadata. | helm/order-service |
| Release | A deployed instance of a Chart. | order-dev |
| Repository | A place from which Charts can be discovered/downloaded. | Used for third-party charts |
| Values | Configuration supplied to templates. | values.yaml, values-dev.yaml |
| Template | Kubernetes YAML containing Helm expressions. | templates/deployment.yaml |
| Revision | A versioned state of a Helm Release. | helm history order-dev |
| Manifest | Rendered Kubernetes YAML generated by Helm. | helm get manifest |

| Command | Purpose | Example |
| --- | --- | --- |
| helm version | Check Helm version. | helm version |
| helm env | Display Helm environment settings. | helm env |
| helm create | Create a starter Chart. | helm create helm/order-service |
| helm lint | Check a Chart for common problems. | helm lint helm/order-service |
| helm template | Render templates locally without deploying. | helm template order-dev helm/order-service -n order-dev |
| helm install | Install a Chart as a new Release. | helm install order-dev helm/order-service -n order-dev |
| helm upgrade | Upgrade an existing Release. | helm upgrade order-dev helm/order-service -n order-dev -f helm/order-service/values-dev.yaml |
| helm upgrade --install | Install if missing; otherwise upgrade. | helm upgrade --install order-dev helm/order-service -n order-dev -f helm/order-service/values-dev.yaml |
| helm status | Show Release status and resources. | helm status order-dev -n order-dev |
| helm list | List Releases. | helm list -A |
| helm history | Show Release revisions. | helm history order-dev -n order-dev |
| helm rollback | Roll back to a previous revision. | helm rollback order-dev 8 -n order-dev |
| helm uninstall | Remove a Release and its managed resources. | helm uninstall order-dev -n order-dev |
| helm get values | Show values associated with a Release. | helm get values order-dev -n order-dev --all |
| helm get manifest | Show rendered Kubernetes manifests stored for the Release. | helm get manifest order-dev -n order-dev |
| helm get all | Show Release information, values and manifests. | helm get all order-dev -n order-dev |
| helm get hooks | Show Helm hooks associated with a Release. | helm get hooks order-dev -n order-dev |
| helm show chart | Show Chart metadata. | helm show chart helm/order-service |
| helm show values | Show a Chart's default values. | helm show values helm/order-service |
| helm show readme | Show Chart README if supplied. | helm show readme helm/order-service |
| helm repo add | Register a Chart repository. | helm repo add <name> <repository-url> |
| helm repo list | List configured repositories. | helm repo list |
| helm repo update | Refresh repository indexes. | helm repo update |
| helm search repo | Search configured repositories. | helm search repo nginx |
| helm pull | Download a Chart locally. | helm pull <repo/chart> |
| helm package | Package a Chart into a .tgz archive. | helm package helm/order-service |
| helm dependency update | Download/update dependencies declared by Chart.yaml. | helm dependency update helm/order-service |
| helm dependency list | List Chart dependencies. | helm dependency list helm/order-service |
| helm test | Run a Chart's Helm test hooks. | helm test order-dev -n order-dev |

|  | kubectl | Helm |
| --- | --- | --- |
| Primary role | Direct Kubernetes resource operations | Package, template and manage application releases |
| Example | kubectl apply -f deployment.yaml | helm upgrade --install order-dev ./helm/order-service |
| Templating | No built-in Helm templating | Yes |
| Release history | Not Helm release history | Yes |
| Rollback | Manual/resource-specific approaches | helm rollback |
| Reuse | Possible through YAML tooling | Charts + values are designed for reuse |

# Production Architecture: Where Helm Fits

This section connects the Helm concepts in this lesson to the production architecture of the `enterprise-order-platform` project.

## 1. Complete Production Architecture

```text
                              ┌──────────────────┐
                              │    Developer     │
                              └────────┬─────────┘
                                       │
                                       ▼
                              ┌──────────────────┐
                              │     GitHub       │
                              │   Source Code    │
                              └────────┬─────────┘
                                       │
                                       ▼
                         ┌──────────────────────────┐
                         │     Azure DevOps         │
                         │       Pipeline           │
                         │                          │
                         │  Build → Test → Docker   │
                         │          Build           │
                         └────────────┬─────────────┘
                                      │
                                      ▼
                         ┌──────────────────────────┐
                         │ Azure Container Registry │
                         │          (ACR)           │
                         │                          │
                         │ order-service:VERSION    │
                         └────────────┬─────────────┘
                                      │
                                      │ Image Pull
                                      ▼
        ┌─────────────────────────────────────────────────────────┐
        │                         AKS                              │
        │                                                         │
        │   ┌─────────────────────────────────────────────────┐   │
        │   │                 Istio Layer                     │   │
        │   │                                                 │   │
        │   │      Istio Ingress Gateway                      │   │
        │   │              │                                  │   │
        │   │              ▼                                  │   │
        │   │       VirtualService                            │   │
        │   └──────────────┬──────────────────────────────────┘   │
        │                  │                                      │
        │                  ▼                                      │
        │   ┌─────────────────────────────────────────────────┐   │
        │   │             order-service Pod                   │   │
        │   │                                                 │   │
        │   │   ┌──────────────────┐  ┌───────────────────┐  │   │
        │   │   │  Spring Boot     │  │   Envoy Sidecar   │  │   │
        │   │   │  order-service   │◄─┤      Proxy        │  │   │
        │   │   └────────┬─────────┘  └───────────────────┘  │   │
        │   └────────────┼────────────────────────────────────┘   │
        │                │                                        │
        │                ▼                                        │
        │       ┌─────────────────┐                               │
        │       │   PostgreSQL    │                               │
        │       └─────────────────┘                               │
        │                                                         │
        │       ConfigMap ──► Application Configuration           │
        │       Secret ─────► Credentials                         │
        │       Key Vault ──► Production Secrets                  │
        └─────────────────────────────────────────────────────────┘
```

### What each layer does

| Component | Responsibility |
|---|---|
| GitHub | Stores application source code and Helm charts |
| Azure DevOps | Builds, tests, packages and deploys the application |
| Azure Container Registry | Stores versioned Docker images |
| AKS | Runs the Kubernetes workloads |
| Helm | Packages and deploys Kubernetes resources |
| Istio | Handles traffic management, security and service-to-service networking |
| Istio Ingress Gateway | Entry point for external HTTP traffic |
| VirtualService | Defines how incoming traffic is routed |
| Spring Boot | Runs the business/application logic |
| Envoy Sidecar | Handles service-mesh networking for the application pod |
| ConfigMap | Stores non-sensitive configuration |
| Kubernetes Secret | Stores Kubernetes-managed sensitive values |
| Azure Key Vault | Recommended production secret store |
| PostgreSQL | Stores application data |

## 2. Where Helm Fits

Helm sits between the deployment process and Kubernetes resources.

```text
                       HELM
                         │
                         ▼
              ┌──────────────────────┐
              │     Helm Chart       │
              │                      │
              │ Chart.yaml           │
              │ values.yaml          │
              │ values-dev.yaml      │
              │ templates/           │
              └──────────┬───────────┘
                         │
                         │ helm template
                         │ helm install
                         │ helm upgrade
                         ▼
              ┌──────────────────────┐
              │ Kubernetes Resources │
              │                      │
              │ Deployment           │
              │ Service              │
              │ ConfigMap            │
              │ Secret               │
              │ Gateway              │
              │ VirtualService       │
              │ PeerAuthentication   │
              └──────────┬───────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │ Kubernetes / AKS     │
              │                      │
              │ Pods                 │
              │ Services             │
              │ Networking           │
              │ Config                │
              └──────────────────────┘
```

**Important:** Helm does not run your application and Helm is not the service mesh.

Helm is the **packaging and deployment tool**. Kubernetes runs the workloads, while Istio manages service-mesh networking.

## 3. Helm's Role in the CI/CD Flow

In the production version of this project, the flow can be understood as:

```text
Developer
    │
    ▼
GitHub
    │
    ▼
Azure DevOps Pipeline
    │
    ├── Compile Java application
    ├── Run unit tests
    ├── Build Docker image
    ├── Tag image
    │       │
    │       ▼
    │   ACR
    │
    └── Helm Upgrade
             │
             ▼
       Helm Chart
             │
             ├── values.yaml
             ├── values-dev.yaml
             └── templates/
                     │
                     ▼
                 Kubernetes
                     │
                     ▼
                    AKS
```

For example:

```powershell
helm upgrade order-dev helm/order-service `
  -n order-dev `
  -f helm/order-service/values-dev.yaml `
  --set image.tag=0.1.6
```

Helm takes the chart templates, combines them with the selected values, renders the Kubernetes manifests, and applies the desired state to the cluster.

## 4. Mapping This Architecture to Our Project

Our current local Docker Desktop environment is intentionally similar to the future AKS architecture:

```text
LOCAL DEVELOPMENT                         PRODUCTION

Docker Desktop Kubernetes                 AKS
        │                                  │
        ├── order-service Pod              ├── order-service Pod
        │      ├── Spring Boot             │      ├── Spring Boot
        │      └── Envoy                   │      └── Envoy
        │                                  │
        ├── Istio                          ├── Istio
        │                                  │
        ├── ConfigMap                      ├── ConfigMap
        ├── Secret                         ├── Key Vault
        │                                  │
        └── PostgreSQL                     └── Managed PostgreSQL
```

The purpose of the local setup is to learn the same deployment concepts before moving them to Azure.

## 5. Why This Architecture Matters for Helm

Without Helm, we would have to maintain and manually apply many Kubernetes YAML files for each environment.

For example:

```text
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f configmap.yaml
kubectl apply -f gateway.yaml
kubectl apply -f virtualservice.yaml
kubectl apply -f peerauthentication.yaml
```

With Helm, these resources are grouped into a reusable chart:

```text
helm/order-service/
│
├── Chart.yaml
├── values.yaml
├── values-dev.yaml
│
└── templates/
    ├── deployment.yaml
    ├── service.yaml
    ├── configmap.yaml
    ├── gateway.yaml
    ├── virtualservice.yaml
    └── peerauthentication.yaml
```

Then one command can deploy or upgrade the complete application:

```powershell
helm upgrade order-dev helm/order-service `
  -n order-dev `
  -f helm/order-service/values-dev.yaml
```

This is one of the main reasons Helm becomes valuable as the project grows from a local learning project into a production-grade deployment.

# Lesson 6 — Helm: Complete Guide for Enterprise Order Platform

> **Project:** `enterprise-order-platform`  
> **Lesson:** 6 — Helm  
> **Purpose:** Complete reference for everything learned in the Helm chapter, including concepts, commands, templates, environment configuration, troubleshooting, advanced topics, and production usage.

---

# 1. What Is Helm?

Helm is a package manager and release-management tool for Kubernetes.

Kubernetes normally requires us to create and maintain YAML files such as:

- Deployment
- Service
- ConfigMap
- Secret
- Gateway
- VirtualService
- PeerAuthentication

For one application this is manageable. For many environments and services, maintaining large numbers of almost-identical YAML files becomes difficult.

Helm solves this by allowing us to create a reusable **Chart** containing templates and configuration values.

Conceptually:

```text
Kubernetes YAML
       +
Templates
       +
Environment values
       |
       v
      Helm
       |
       v
Rendered Kubernetes manifests
       |
       v
   Kubernetes
```

---

# 2. Why Do We Need Helm?

Suppose we have three environments:

```text
DEV
QA
PROD
```

Without Helm, we might have:

```text
k8s/
├── dev/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── configmap.yaml
│
├── qa/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── configmap.yaml
│
└── prod/
    ├── deployment.yaml
    ├── service.yaml
    └── configmap.yaml
```

This creates duplication.

With Helm:

```text
helm/
└── order-service/
    ├── Chart.yaml
    ├── values.yaml
    ├── values-dev.yaml
    ├── values-qa.yaml
    ├── values-prod.yaml
    └── templates/
        ├── deployment.yaml
        ├── service.yaml
        ├── configmap.yaml
        └── ...
```

The templates remain reusable while environment-specific values change.

---

# 3. What Happens Without Helm?

Imagine the application needs:

```yaml
replicas: 1
```

in development and:

```yaml
replicas: 3
```

in production.

Without Helm, we might maintain separate YAML files.

With Helm:

```yaml
# values-dev.yaml
replicaCount: 1
```

```yaml
# values-prod.yaml
replicaCount: 3
```

The template remains:

```yaml
replicas: {{ .Values.replicaCount }}
```

Helm inserts the appropriate value.

---

# 4. Helm Architecture

The important concepts are:

```text
                    Helm CLI
                       |
                       v
                    Chart
                 /          \
                /            \
          Templates        Values
                \            /
                 \          /
                    Render
                      |
                      v
               Kubernetes YAML
                      |
                      v
                  Kubernetes
```

A deployed Helm application is called a **Release**.

Our release is:

```text
order-dev
```

The chart is:

```text
order-service
```

---

# 5. Helm Chart

A Helm Chart is a package containing the files needed to deploy an application.

Typical structure:

```text
order-service/
├── Chart.yaml
├── values.yaml
├── values-dev.yaml
├── templates/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   ├── gateway.yaml
│   ├── virtualservice.yaml
│   ├── peerauthentication.yaml
│   └── NOTES.txt
└── charts/
```

---

# 6. Chart.yaml

Example:

```yaml
apiVersion: v2
name: order-service
description: Helm chart for order-service

type: application

version: 0.1.0

appVersion: "0.1.5"
```

## Important fields

### `name`

The chart name:

```yaml
name: order-service
```

### `version`

The Helm chart version:

```yaml
version: 0.1.0
```

### `appVersion`

The application version:

```yaml
appVersion: "0.1.5"
```

These are different.

For example:

```text
Chart version:       0.1.0
Application image:   order-service:0.1.6
```

The chart can remain version `0.1.0` while the application image changes, although production teams normally version both deliberately.

---

# 7. values.yaml

`values.yaml` contains default configuration values.

Our project:

```yaml
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

config:
  enabled: true
  environment: "dev"
  orderTimeoutSeconds: "30"

resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

Think of `values.yaml` as the default configuration for the chart.

---

# 8. values-dev.yaml

Environment-specific configuration can be kept separately.

Example:

```yaml
replicaCount: 1

image:
  tag: "0.1.6"

database:
  url: jdbc:postgresql://host.docker.internal:5432/orderdb
```

Deploy with:

```powershell
helm upgrade --install order-dev helm/order-service `
  -n order-dev `
  -f helm/order-service/values-dev.yaml
```

---

# 9. How Helm Combines values.yaml and values-dev.yaml

This is important.

Helm starts with the chart's default:

```text
values.yaml
```

Then applies the supplied override file:

```text
values-dev.yaml
```

Conceptually:

```text
values.yaml
       +
values-dev.yaml
       |
       v
Final .Values
       |
       v
Templates
```

If both contain:

```yaml
replicaCount: 1
```

the dev value wins.

If `values.yaml` contains:

```yaml
config:
  enabled: true
  environment: dev
  orderTimeoutSeconds: "30"
```

and `values-dev.yaml` contains only:

```yaml
image:
  tag: "0.1.6"
```

the config values still come from `values.yaml`.

### What if a property exists only in values-dev.yaml?

That is completely valid.

For example:

```yaml
# values-dev.yaml
newProperty: "hello"
```

The chart will have:

```text
.Values.newProperty
```

available.

However, if no template uses:

```text
.Values.newProperty
```

it will not appear in the Kubernetes manifests.

Important:

> A value in a values file does not automatically become an environment variable.

The template must explicitly use it.

---

# 10. Helm Templates

A template contains normal Kubernetes YAML plus Helm expressions.

Example:

```yaml
spec:
  replicas: {{ .Values.replicaCount }}
```

If:

```yaml
replicaCount: 1
```

Helm renders:

```yaml
spec:
  replicas: 1
```

---

# 11. `.Values`

`.Values` accesses values supplied to Helm.

Examples:

```yaml
{{ .Values.replicaCount }}
```

```yaml
{{ .Values.image.repository }}
```

```yaml
{{ .Values.image.tag }}
```

```yaml
{{ .Values.database.url }}
```

Nested values are accessed using dots.

---

# 12. Template Functions

We used functions such as:

```yaml
{{ .Values.database.url | quote }}
```

`quote` ensures the value is rendered as a YAML string.

We also used:

```yaml
{{- toYaml .Values.resources | nindent 12 }}
```

`toYaml` converts structured values to YAML.

`nindent` adds indentation.

---

# 13. Our Deployment Template

Our Deployment uses:

```yaml
spec:
  replicas: {{ .Values.replicaCount }}
```

and:

```yaml
image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
```

and:

```yaml
imagePullPolicy: {{ .Values.image.pullPolicy }}
```

This means:

```text
values.yaml
     |
     v
.Values.image.repository
.Values.image.tag
     |
     v
Deployment
```

For our current dev configuration:

```text
order-service:0.1.6
```

---

# 14. ConfigMap

Our ConfigMap template:

```yaml
{{- if .Values.config.enabled }}

apiVersion: v1
kind: ConfigMap

metadata:
  name: order-service-config

data:
  APP_ENVIRONMENT: {{ .Values.config.environment | quote }}
  ORDER_TIMEOUT_SECONDS: {{ .Values.config.orderTimeoutSeconds | quote }}

{{- end }}
```

This demonstrates a conditional:

```yaml
if .Values.config.enabled
```

If enabled:

```text
ConfigMap is created.
```

If disabled:

```text
ConfigMap is not rendered.
```

---

# 15. ConfigMap Values

Our values contain:

```yaml
config:
  enabled: true
  environment: "dev"
  orderTimeoutSeconds: "30"
```

Helm renders:

```yaml
data:
  APP_ENVIRONMENT: "dev"
  ORDER_TIMEOUT_SECONDS: "30"
```

---

# 16. ConfigMap to Pod

Our Deployment contains:

```yaml
envFrom:
  - configMapRef:
      name: order-service-config
```

Therefore Kubernetes injects the ConfigMap entries into the container.

Conceptually:

```text
values.yaml
     |
     v
Helm template
     |
     v
ConfigMap
     |
     v
envFrom
     |
     v
Container environment
```

We verified:

```powershell
kubectl exec -n order-dev <pod> `
  -c order-service `
  -- printenv APP_ENVIRONMENT
```

Output:

```text
dev
```

And:

```powershell
kubectl exec -n order-dev <pod> `
  -c order-service `
  -- printenv ORDER_TIMEOUT_SECONDS
```

Output:

```text
30
```

---

# 17. Kubernetes Secrets

Our Deployment references:

```yaml
env:
  - name: SPRING_DATASOURCE_USERNAME
    valueFrom:
      secretKeyRef:
        name: order-db-secret
        key: SPRING_DATASOURCE_USERNAME
```

and:

```yaml
- name: SPRING_DATASOURCE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: order-db-secret
      key: SPRING_DATASOURCE_PASSWORD
```

For this lesson we intentionally do not go deep into secret management.

Production secret management will be covered later with:

```text
Azure Key Vault
        +
Managed Identity
        +
AKS
```

---

# 18. Helm and Istio

Our Helm chart also manages Istio resources.

We have templates for:

```text
Gateway
VirtualService
PeerAuthentication
```

Therefore Helm becomes the deployment mechanism for both:

```text
Kubernetes resources
```

and:

```text
Istio resources
```

---

# 19. Helm Gateway

Our Gateway contains:

```yaml
apiVersion: networking.istio.io/v1
kind: Gateway

metadata:
  name: order-gateway
```

It selects:

```yaml
selector:
  istio: ingressgateway
```

and listens on:

```yaml
port:
  number: 80
```

for:

```text
order.local
```

---

# 20. Helm VirtualService

Our VirtualService routes:

```text
order.local
```

to:

```text
order-service:8080
```

It also contains:

```yaml
timeout: 2s
```

and retries:

```yaml
retries:
  attempts: 2
  perTryTimeout: 1s
  retryOn: 5xx,connect-failure,reset,refused-stream
```

Thus Helm manages the Istio traffic configuration as code.

---

# 21. Helm PeerAuthentication

We configured:

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication

spec:
  mtls:
    mode: STRICT
```

This enables strict mTLS for the configured scope.

---

# 22. Main Helm Commands

## `helm version`

Checks Helm version:

```powershell
helm version
```

---

## `helm create`

Creates a starter chart:

```powershell
helm create my-chart
```

For our project we built/customized the chart rather than relying on the default generated structure.

---

## `helm lint`

Checks chart structure and common errors:

```powershell
helm lint helm/order-service `
  -f helm/order-service/values-dev.yaml
```

Our result:

```text
1 chart(s) linted, 0 chart(s) failed
```

The icon warning is informational.

---

# 23. helm template

Renders the chart locally without deploying it.

```powershell
helm template order-dev helm/order-service `
  -n order-dev `
  -f helm/order-service/values-dev.yaml
```

This is one of the most useful debugging commands.

For example, we verified:

```text
image: order-service:0.1.6
```

and:

```text
APP_ENVIRONMENT: "dev"
ORDER_TIMEOUT_SECONDS: "30"
```

---

# 24. Filtering Rendered Output

PowerShell can filter Helm output:

```powershell
helm template order-dev helm/order-service `
  -n order-dev `
  -f helm/order-service/values-dev.yaml |
  Select-String -Pattern "image:|SPRING_DATASOURCE_URL"
```

This is useful for quickly checking particular values.

---

# 25. helm install

Creates a new Helm release:

```powershell
helm install order-dev helm/order-service `
  -n order-dev `
  --create-namespace `
  -f helm/order-service/values-dev.yaml
```

If the release already exists, installation fails.

---

# 26. helm upgrade

Updates an existing release:

```powershell
helm upgrade order-dev helm/order-service `
  -n order-dev `
  -f helm/order-service/values-dev.yaml
```

We used this repeatedly in the project.

---

# 27. helm upgrade --install

This is very useful for CI/CD:

```powershell
helm upgrade --install order-dev helm/order-service `
  -n order-dev `
  --create-namespace `
  -f helm/order-service/values-dev.yaml
```

Meaning:

```text
Does release exist?
       |
    +--+--+
    |     |
   YES    NO
    |     |
 Upgrade Install
```

---

# 28. helm status

Checks the current release:

```powershell
helm status order-dev -n order-dev
```

We used this to verify:

```text
STATUS: deployed
```

and inspect:

```text
Deployment
Service
ConfigMap
Gateway
VirtualService
PeerAuthentication
Pod
```

---

# 29. helm history

Shows release revisions:

```powershell
helm history order-dev -n order-dev
```

Our project demonstrated why this matters.

We had:

```text
Revision 3 → failed
Revision 4 → failed
Revision 6 → superseded
Revision 7 → superseded
Revision 8 → deployed
...
```

This gives us an operational history.

---

# 30. Helm Release Revisions

Every upgrade can create a new revision.

Example:

```text
Revision 7
Revision 8
Revision 9
Revision 10
Revision 11
```

A failed revision is still useful because it records the failed deployment attempt.

---

# 31. helm get values

Shows user-supplied values for a release.

Example:

```powershell
helm get values order-dev -n order-dev
```

For a particular revision:

```powershell
helm get values order-dev -n order-dev --revision 8
```

We used this to compare revisions.

Example output:

```yaml
USER-SUPPLIED VALUES:
database:
  url: jdbc:postgresql://host.docker.internal:5432/orderdb
image:
  tag: 0.1.6
replicaCount: 1
```

---

# 32. Important: User-Supplied vs Computed Values

`helm get values` normally shows user-supplied values.

To inspect computed values:

```powershell
helm get values order-dev `
  -n order-dev `
  --all
```

This can show defaults combined with overrides.

---

# 33. helm rollback

Rollback a release:

```powershell
helm rollback order-dev 8 -n order-dev
```

This restores the specified Helm revision.

Important:

```text
Helm rollback
    ≠
Git rollback
```

Helm manages deployed releases.

Git manages source code and configuration history.

---

# 34. Dry Run

Modern syntax:

```powershell
helm upgrade order-dev helm/order-service `
  -n order-dev `
  -f helm/order-service/values-dev.yaml `
  --dry-run=client
```

This renders and validates the client-side operation without applying it.

We encountered the warning:

```text
--dry-run is deprecated
```

because older shorthand syntax was used.

Use:

```text
--dry-run=client
```

going forward.

---

# 35. The Difference Between template and dry-run

### `helm template`

Primarily:

```text
Render chart → show YAML
```

### `helm upgrade --dry-run=client`

Primarily:

```text
Simulate an upgrade → show what Helm would apply
```

Both are useful before real deployment.

---

# 36. Real Upgrade Workflow

Recommended:

```text
helm lint
      ↓
helm template
      ↓
helm upgrade --dry-run=client
      ↓
helm upgrade --install
      ↓
kubectl rollout status
      ↓
helm status
      ↓
helm test
```

---

# 37. Helm Upgrade Conflict We Encountered

We encountered a real Helm/Kubernetes problem.

Helm attempted to change:

```yaml
spec.selector.matchLabels
```

from:

```yaml
app: order-service
```

to:

```yaml
app.kubernetes.io/name: order-service
app.kubernetes.io/instance: order-dev
```

Kubernetes rejected this because:

```text
Deployment.spec.selector
```

is immutable after creation.

The error included:

```text
field is immutable
```

This is an important production lesson.

---

# 38. Kubernetes Immutable Fields

Some Kubernetes fields cannot be changed after a resource is created.

For a Deployment, the selector is one of the important immutable fields.

Therefore:

```yaml
selector:
  matchLabels:
    app: order-service
```

must remain stable.

We restored the existing selector.

---

# 39. Labels vs Selectors

A label:

```yaml
labels:
  app: order-service
```

identifies a resource.

A selector:

```yaml
selector:
  app: order-service
```

finds resources with that label.

For our Service:

```text
Service selector
      |
      v
app=order-service
      |
      v
Pod label
app=order-service
```

If these do not match, the Service cannot find the intended Pods.

---

# 40. Helm Ownership and kubectl Conflicts

We also encountered conflicts such as:

```text
conflict with "kubectl-client-side-apply"
```

This happened because a resource field had previously been managed by `kubectl`.

General production principle:

> Avoid having multiple deployment tools independently manage the same fields of the same Kubernetes resource.

Once Helm owns a workload, let Helm manage it.

---

# 41. Helm Hooks

Helm hooks allow Kubernetes resources to execute at lifecycle points.

Examples:

```text
pre-install
post-install
pre-upgrade
post-upgrade
pre-rollback
post-rollback
pre-delete
post-delete
test
```

Example:

```yaml
metadata:
  annotations:
    "helm.sh/hook": post-install
```

---

# 42. Hook Example

```yaml
apiVersion: batch/v1
kind: Job

metadata:
  name: order-service-post-install

  annotations:
    "helm.sh/hook": post-install
    "helm.sh/hook-delete-policy": hook-succeeded

spec:
  template:
    spec:
      restartPolicy: Never

      containers:
        - name: setup
          image: busybox:1.36

          command:
            - sh
            - -c
            - |
              echo "Order Service installed"
```

Hooks are useful for special lifecycle operations.

Do not use hooks for ordinary resources that can be managed normally.

---

# 43. NOTES.txt

A chart can contain:

```text
templates/NOTES.txt
```

Example:

```text
Order Service has been deployed.

Release:
  {{ .Release.Name }}

Namespace:
  {{ .Release.Namespace }}

Check Pods:

  kubectl get pods -n {{ .Release.Namespace }}

Check Helm status:

  helm status {{ .Release.Name }} -n {{ .Release.Namespace }}
```

After installation or upgrade, Helm displays these notes.

This helps developers and operators know what to do next.

---

# 44. Helm Tests

A Helm test is commonly implemented using a Kubernetes Job with:

```yaml
"helm.sh/hook": test
```

Example:

```yaml
metadata:
  annotations:
    "helm.sh/hook": test
```

Run:

```powershell
helm test order-dev -n order-dev
```

Difference:

```text
helm lint
  → validates chart

helm template
  → renders chart

helm test
  → tests deployed release
```

---

# 45. Packaging a Helm Chart

Package the chart:

```powershell
helm package helm/order-service
```

This creates:

```text
order-service-0.1.0.tgz
```

The package can later be stored in a chart repository or OCI-compatible registry.

---

# 46. Helm Dependencies

A chart can depend on other charts.

Example:

```yaml
dependencies:
  - name: redis
    version: 20.0.0
    repository: https://example.com/charts
```

Conceptually:

```text
order-service
    |
    +-- redis
    +-- kafka
    +-- other dependency
```

For our project, we are not using Helm to manage the production database.

Later Azure architecture will use appropriate managed services.

---

# 47. Environment-Specific Values

A common structure:

```text
values.yaml
values-dev.yaml
values-qa.yaml
values-prod.yaml
```

Example:

```yaml
# values-dev.yaml
replicaCount: 1
```

```yaml
# values-prod.yaml
replicaCount: 3
```

The same template can then be deployed to different environments.

---

# 48. Resource Configuration

Our values contain:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 256Mi

  limits:
    cpu: 500m
    memory: 512Mi
```

The template uses:

```yaml
resources:
  {{- toYaml .Values.resources | nindent 12 }}
```

This allows environment-specific resource tuning.

---

# 49. Conditional Resources

We used:

```yaml
{{- if .Values.config.enabled }}
```

This allows resources to be conditionally created.

For example:

```yaml
config:
  enabled: false
```

means the ConfigMap will not be rendered.

This is powerful for reusable charts.

---

# 50. Required Values

Helm can fail early if an important value is missing.

Example:

```yaml
image: "{{ required "image.tag is required" .Values.image.tag }}"
```

If the value is missing, Helm reports an error instead of producing an invalid deployment.

---

# 51. Production Helm Best Practices

### Keep environment values separate

```text
values-dev.yaml
values-qa.yaml
values-prod.yaml
```

### Avoid hardcoding

Prefer:

```yaml
replicas: {{ .Values.replicaCount }}
```

instead of:

```yaml
replicas: 3
```

### Validate before deployment

```powershell
helm lint
```

```powershell
helm template
```

```powershell
helm upgrade --dry-run=client
```

### Keep selectors stable

Never casually change Deployment selectors.

### Keep Helm as the owner

Avoid mixing `kubectl apply` and Helm management for the same resource.

### Keep secrets out of ordinary values files

We will learn the Azure production approach later.

---

# 52. Helm Does Not Replace Kubernetes

This distinction is critical.

Kubernetes provides:

- container scheduling
- Pods
- Deployments
- Services
- ConfigMaps
- Secrets
- networking
- self-healing
- scaling

Helm provides:

- templating
- packaging
- configuration management
- release management
- version history
- upgrade
- rollback

Think:

```text
Kubernetes
=
container orchestration platform

Helm
=
Kubernetes application packaging and release management
```

---

# 53. Helm Does Not Replace CI/CD

Helm is one part of the deployment pipeline.

Our future Azure DevOps pipeline will look like:

```text
Developer
    |
    v
Git
    |
    v
Azure DevOps Pipeline
    |
    +--> Build
    |
    +--> Unit tests
    |
    +--> Docker build
    |
    +--> Push image to ACR
    |
    +--> Helm lint
    |
    +--> Helm template
    |
    +--> Helm upgrade --install
    |
    v
AKS
```

---

# 54. Helm in Our Project Architecture

Our current local architecture:

```text
                    Docker Desktop
                         |
                    Kubernetes
                         |
             +-----------+-----------+
             |                       |
             v                       v
       Istio Gateway           order-service
             |                       |
             v                       |
       VirtualService                |
             |                       |
             +-----------> Service --+
                                  |
                                  v
                               Pod
                            /        \
                           /          \
                    Spring Boot      Envoy
                         |
                         v
                     PostgreSQL
```

Helm sits above these resources as the deployment/package manager:

```text
                    Helm
                     |
                     v
        +------------+-------------+
        |            |             |
        v            v             v
   Deployment    Service      ConfigMap
        |
        v
       Pod
        |
        +--> Spring Boot
        +--> Envoy

Helm also manages:
    |
    +--> Gateway
    +--> VirtualService
    +--> PeerAuthentication
```

---

# 55. Complete Helm Workflow for Our Project

## Step 1 — Build application

```powershell
.\mvnw.cmd clean package
```

## Step 2 — Build Docker image

```powershell
docker build -t order-service:0.1.6 .
```

## Step 3 — Update environment values

```yaml
image:
  tag: "0.1.6"
```

## Step 4 — Lint

```powershell
helm lint helm/order-service `
  -f helm/order-service/values-dev.yaml
```

## Step 5 — Render

```powershell
helm template order-dev helm/order-service `
  -n order-dev `
  -f helm/order-service/values-dev.yaml
```

## Step 6 — Dry run

```powershell
helm upgrade order-dev helm/order-service `
  -n order-dev `
  -f helm/order-service/values-dev.yaml `
  --dry-run=client
```

## Step 7 — Deploy

```powershell
helm upgrade --install order-dev helm/order-service `
  -n order-dev `
  -f helm/order-service/values-dev.yaml
```

## Step 8 — Verify

```powershell
helm status order-dev -n order-dev
```

## Step 9 — Check Pods

```powershell
kubectl get deployment,pods -n order-dev
```

## Step 10 — Check rollout

```powershell
kubectl rollout status deployment/order-service -n order-dev
```

## Step 11 — Run tests

```powershell
helm test order-dev -n order-dev
```

when the chart contains the test hook.

---

# 56. Important Commands Cheat Sheet

| Command | Purpose |
|---|---|
| `helm version` | Check Helm version |
| `helm create` | Create starter chart |
| `helm lint` | Validate chart |
| `helm template` | Render templates |
| `helm install` | Install release |
| `helm upgrade` | Upgrade release |
| `helm upgrade --install` | Install or upgrade |
| `helm status` | Show release status |
| `helm history` | Show release history |
| `helm rollback` | Roll back release |
| `helm get values` | Show release values |
| `helm get manifest` | Show deployed manifest |
| `helm test` | Run chart tests |
| `helm package` | Package chart |
| `helm list` | List releases |
| `helm uninstall` | Remove release |

---

# 57. Useful Kubernetes Verification Commands

Check deployment:

```powershell
kubectl get deployment -n order-dev
```

Check Pods:

```powershell
kubectl get pods -n order-dev
```

Check Service:

```powershell
kubectl get svc -n order-dev
```

Check ConfigMap:

```powershell
kubectl get configmap -n order-dev
```

Describe deployment:

```powershell
kubectl describe deployment order-service -n order-dev
```

Check logs:

```powershell
kubectl logs deployment/order-service -n order-dev -c order-service
```

Check container environment:

```powershell
kubectl exec -n order-dev <pod> `
  -c order-service `
  -- printenv APP_ENVIRONMENT
```

---

# 58. What We Learned From Our Actual Helm Errors

These were not just theoretical exercises.

## Error 1 — kubectl ownership conflict

We saw:

```text
conflict with "kubectl-client-side-apply"
```

Lesson:

```text
Avoid multiple tools managing the same resource fields.
```

---

## Error 2 — immutable selector

We saw:

```text
spec.selector: ... field is immutable
```

Lesson:

```text
Some Kubernetes fields cannot be changed after creation.
```

---

## Error 3 — Dry-run syntax warning

We saw:

```text
--dry-run is deprecated
```

Lesson:

Use:

```powershell
--dry-run=client
```

---

# 59. Helm Release vs Kubernetes Resources

Our Helm release:

```text
order-dev
```

contains resources such as:

```text
Deployment/order-service
Service/order-service
ConfigMap/order-service-config
Gateway/order-gateway
VirtualService/order-service
PeerAuthentication/order-mtls
```

Therefore:

```text
Helm Release
     |
     +--> Kubernetes resources
```

Deleting the Helm release can remove the resources managed by that release.

---

# 60. Helm History and Kubernetes History Are Different

Helm:

```powershell
helm history order-dev -n order-dev
```

tracks Helm release revisions.

Kubernetes:

```powershell
kubectl rollout history deployment/order-service -n order-dev
```

tracks Deployment rollout revisions.

They are related but not identical.

---

# 61. `helm get manifest`

To inspect the manifest stored by Helm:

```powershell
helm get manifest order-dev -n order-dev
```

This is useful when debugging what Helm actually deployed.

---

# 62. `helm list`

List releases:

```powershell
helm list -A
```

or for a namespace:

```powershell
helm list -n order-dev
```

---

# 63. `helm uninstall`

Remove a release:

```powershell
helm uninstall order-dev -n order-dev
```

Use this carefully.

For development environments it can be useful for cleanup.

---

# 64. Helm Secrets — Deferred

We intentionally do not go deeply into Helm secret management in this chapter.

Why?

Because our target production architecture will use Azure services.

Later we will learn:

```text
Azure Key Vault
       |
       v
Managed Identity
       |
       v
AKS
       |
       v
Spring Boot
```

This is more relevant to the production architecture we are building.

---

# 65. Helm and Azure

Our local environment:

```text
Docker Desktop
    |
    v
Local Kubernetes
    |
    v
Istio
    |
    v
Helm
```

Later:

```text
Azure
 |
 +--> AKS
 |
 +--> ACR
 |
 +--> Key Vault
 |
 +--> API Management
 |
 +--> Azure DevOps
 |
 +--> Application Insights
 |
 +--> Azure Monitor
```

Helm remains relevant.

The major change is that Kubernetes will run in AKS rather than Docker Desktop.

---

# 66. Future Azure Deployment Flow

```text
Developer
    |
    v
Git Repository
    |
    v
Azure DevOps Pipeline
    |
    +--> Maven build
    |
    +--> Unit tests
    |
    +--> Docker build
    |
    v
Azure Container Registry
    |
    v
Helm
    |
    v
AKS
    |
    v
Istio
    |
    v
Spring Boot service
```

---

# 67. Helm Interview Questions

## What is Helm?

Helm is a Kubernetes package manager and release-management tool.

## What is a Chart?

A package containing Kubernetes templates and configuration.

## What is a Release?

A deployed instance of a Helm chart.

## What is values.yaml?

Default chart configuration.

## What is values-dev.yaml?

Environment-specific override configuration.

## What is `.Values`?

Helm's object for accessing configuration values inside templates.

## What does `helm template` do?

Renders the chart locally without deploying it.

## What does `helm lint` do?

Checks the chart for common errors and structural issues.

## What does `helm upgrade` do?

Updates an existing release.

## What does `helm rollback` do?

Restores a previous Helm release revision.

## What is `helm upgrade --install`?

It upgrades an existing release or installs it if it does not exist.

## What is a Helm hook?

A resource executed at a Helm lifecycle event.

## What is `NOTES.txt`?

A template for displaying post-install/post-upgrade instructions.

## What is a Helm test?

A test resource associated with a Helm release, usually implemented as a Kubernetes Job.

## Why use environment-specific values?

To reuse the same chart while changing configuration between environments.

## Why did our Deployment selector upgrade fail?

Because Kubernetes Deployment selectors are immutable after creation.

## Does Helm replace Kubernetes?

No. Helm manages packaging and releases; Kubernetes runs and manages workloads.

---

# 68. Lesson 6 Final Mental Model

Remember:

```text
                Helm Chart
               /          \
              /            \
        Templates         Values
             |               |
             +-------+-------+
                     |
                     v
                  Helm
                     |
                     v
             Rendered manifests
                     |
                     v
                Kubernetes
                     |
          +----------+----------+
          |          |          |
          v          v          v
      Deployment   Service   ConfigMap
          |
          v
         Pod
          |
     +----+----+
     |         |
     v         v
Spring Boot  Envoy
```

Istio resources are also managed by Helm:

```text
Helm
 |
 +--> Gateway
 +--> VirtualService
 +--> PeerAuthentication
```

---

# 69. Production Mental Model

The technologies have different responsibilities:

```text
Spring Boot
    ↓
Business application

Docker
    ↓
Application packaging

Kubernetes
    ↓
Container orchestration

Istio
    ↓
Service networking and traffic management

Helm
    ↓
Kubernetes application packaging + release management

Azure
    ↓
Cloud infrastructure

Azure DevOps
    ↓
CI/CD automation
```

---

# 70. Lesson 6 Completion Checklist

You can mark each item when you can explain it without referring to notes.

### Helm fundamentals

- [ ] What is Helm?
- [ ] Why Helm is needed
- [ ] What happens without Helm
- [ ] Helm Chart
- [ ] Helm Release
- [ ] Helm architecture

### Chart

- [ ] Chart.yaml
- [ ] values.yaml
- [ ] values-dev.yaml
- [ ] templates
- [ ] `.Values`
- [ ] template functions
- [ ] conditionals

### Kubernetes integration

- [ ] Deployment
- [ ] Service
- [ ] ConfigMap
- [ ] Secret references
- [ ] Istio Gateway
- [ ] VirtualService
- [ ] PeerAuthentication

### Commands

- [ ] helm lint
- [ ] helm template
- [ ] helm install
- [ ] helm upgrade
- [ ] helm upgrade --install
- [ ] helm status
- [ ] helm history
- [ ] helm rollback
- [ ] helm get values
- [ ] helm get manifest
- [ ] helm test
- [ ] helm package
- [ ] helm list
- [ ] helm uninstall

### Advanced

- [ ] Helm hooks
- [ ] NOTES.txt
- [ ] Helm tests
- [ ] Dependencies
- [ ] Chart packaging
- [ ] Chart version vs app version
- [ ] Immutable Kubernetes fields
- [ ] Labels vs selectors
- [ ] Helm ownership
- [ ] Production practices
- [ ] CI/CD integration

---

# 71. What Comes Next?

After completing Helm, the project moves to:

# Lesson 7 — Azure Fundamentals

The next stage is not simply "open Azure Portal."

We will first understand the Azure architecture required for our project.

Expected progression:

```text
Lesson 6
Helm
   ↓
Lesson 7
Azure Fundamentals
   ↓
Resource Groups
   ↓
Azure Container Registry
   ↓
AKS
   ↓
Azure DevOps
   ↓
Azure Pipelines
   ↓
Managed Identity
   ↓
Key Vault
   ↓
API Management
   ↓
Application Insights
   ↓
Azure Monitor
```

The local Kubernetes + Istio + Helm work we completed is the foundation for understanding AKS.

---

# 72. Final Lesson 6 Summary

At the end of this lesson, the deployment flow should be clear:

```text
Java/Spring Boot
       |
       v
Docker image
       |
       v
Helm values
       |
       v
Helm templates
       |
       v
Rendered Kubernetes YAML
       |
       v
Helm Release
       |
       v
Kubernetes
       |
       +--> Deployment
       +--> Service
       +--> ConfigMap
       +--> Secret reference
       |
       +--> Istio Gateway
       +--> VirtualService
       +--> PeerAuthentication
       |
       v
Running application
```

And later:

```text
Git
 ↓
Azure DevOps
 ↓
Build + Test
 ↓
Docker
 ↓
ACR
 ↓
Helm
 ↓
AKS
 ↓
Istio
 ↓
Spring Boot
 ↓
Azure services
```

**Lesson 6 — Helm is complete when you understand both how Helm works and why each part exists in the deployment architecture.**

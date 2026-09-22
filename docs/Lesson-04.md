# Lesson 4 --- Istio Service Mesh: Traffic Management, Security & Observability

> **Project:** enterprise-order-platform\
> **Environment:** Docker Desktop Kubernetes\
> **Namespace:** `order-dev`\
> **Istio:** 1.31.0\
> **Focus:** What, Why, How, hands-on verification, troubleshooting, and
> interview preparation

------------------------------------------------------------------------

## 1. What This Lesson Is About

In Lesson 3, Kubernetes was responsible for deploying and networking the
`order-service`.

In this lesson, we introduced **Istio** as a service mesh.

The key idea is:

> Kubernetes knows how to run and discover services. Istio adds
> intelligent traffic management, service-to-service security,
> resilience, and observability.

Our first Istio request path intentionally excludes Azure API Management
and NGINX so that the Istio concepts are easy to isolate:

``` text
Client
  |
  v
Istio Ingress Gateway
  |
  |  Gateway + VirtualService
  v
order-service Kubernetes Service
  |
  v
order-service Pod
  |
  +--> Envoy sidecar
  |
  +--> Spring Boot application
```

Later, the complete production architecture will be:

``` text
Client
  |
  v
Microsoft Entra ID
  |
  v
Azure API Management
  |
  v
NGINX Ingress
  |
  v
Istio Ingress Gateway
  |
  v
VirtualService
  |
  v
Order Service
  |
  v
PostgreSQL

Cross-cutting:
Key Vault + Managed Identity
Application Insights
Azure Monitor
Log Analytics
Azure DevOps
ACR
AKS
```

------------------------------------------------------------------------

# 2. Why Do We Need Istio?

Without Istio, an application can still work perfectly well:

``` text
Service A --> Kubernetes Service --> Service B
```

But as the number of services increases, operational requirements become
more difficult.

For example:

-   How do we retry a failed request?
-   How do we enforce request timeouts?
-   How do we gradually send traffic to a new version?
-   How do we encrypt service-to-service traffic?
-   How do we collect consistent service-to-service telemetry?
-   How do we implement traffic policies without adding the same code to
    every Java service?

Istio moves many of these concerns into the platform/network layer.

``` text
                 Application
                     |
              Business Logic
                     |
              Spring Boot
                     |
              Envoy Sidecar
                     |
       +-------------+-------------+
       |             |             |
     mTLS          Retry        Timeout
       |             |             |
       +-------------+-------------+
                     |
                  Network
```

The Java application focuses primarily on business functionality while
Istio handles many communication concerns.

------------------------------------------------------------------------

# 3. Kubernetes vs Istio --- The Most Important Distinction

This distinction is critical for interviews.

## Kubernetes provides

-   Pods
-   Deployments
-   Services
-   Service discovery
-   DNS
-   Scheduling
-   Container lifecycle
-   Basic networking primitives

Example:

``` text
order-service
      |
      v
Kubernetes Service
      |
      v
Order Pods
```

## Istio provides

-   Traffic routing
-   Retries
-   Timeouts
-   mTLS
-   Traffic splitting
-   Canary releases
-   Circuit breaking
-   Request telemetry
-   Service-to-service policy

Example:

``` text
Request
   |
   v
Istio
   |
   +--> timeout
   +--> retry
   +--> mTLS
   +--> routing
   +--> telemetry
   |
   v
Order Service
```

### Interview answer

> Kubernetes provides the service discovery and networking primitives.
> Istio builds a service mesh on top of those primitives and adds
> traffic management, security, resilience, and observability.

------------------------------------------------------------------------

# 4. Istio Architecture

Istio has two major concepts:

## Control Plane

The main component is:

``` text
istiod
```

It manages configuration and distributes it to Envoy proxies.

``` text
Gateway
VirtualService
PeerAuthentication
DestinationRule
       |
       v
     istiod
       |
       | xDS
       v
+------+------+
|             |
v             v
Envoy       Envoy
```

## Data Plane

The data plane consists of Envoy proxies.

For our application:

``` text
Order Pod
+-----------------------------+
|                             |
| Spring Boot Application     |
|       :8080                 |
|                             |
| Envoy Sidecar               |
|       :150xx                |
|                             |
+-----------------------------+
```

Actual application traffic goes through Envoy.

It does **not** go through `istiod`.

Important:

``` text
istiod = control/configuration
Envoy  = actual traffic/data plane
```

------------------------------------------------------------------------

# 5. What Is Envoy?

Envoy is the proxy used by Istio.

The application does not need to implement every networking feature
itself.

For example:

``` text
Client
  |
  v
Envoy
  |
  +--> retry
  +--> timeout
  +--> mTLS
  +--> routing
  +--> telemetry
  |
  v
Application
```

The Envoy sidecar is injected into the application Pod.

Therefore our Pod changed from:

``` text
order-service Pod
1 container
```

to:

``` text
order-service Pod
2 containers

1. order-service
2. istio-proxy
```

We verified this with:

``` powershell
kubectl get pods -n order-dev
```

and saw:

``` text
2/2 Running
```

------------------------------------------------------------------------

# 6. Automatic Sidecar Injection

We enabled automatic Istio injection for `order-dev`:

``` powershell
kubectl label namespace order-dev istio-injection=enabled
```

Then restarted the Deployment:

``` powershell
kubectl rollout restart deployment order-service -n order-dev
```

The newly created Pod received the Envoy sidecar.

Verification:

``` powershell
kubectl get pods -n order-dev
```

Expected:

``` text
order-service-xxxxx   2/2   Running
```

### Why namespace labeling?

Instead of manually adding an Envoy container to every Deployment, Istio
can inject it automatically into Pods in a labeled namespace.

------------------------------------------------------------------------

# 7. Istio Ingress Gateway --- What Is It?

This is one of the most confusing Istio concepts.

The **Istio Ingress Gateway** is an actual workload running Envoy.

We had:

``` text
istio-ingressgateway-xxxxx
```

inside:

``` text
istio-system
```

It is the Envoy entry point for traffic entering the mesh.

``` text
External Client
       |
       v
istio-ingressgateway
       |
       v
VirtualService
       |
       v
order-service
```

------------------------------------------------------------------------

# 8. Three Different Things Called "Gateway"

Keep these separate.

## A. `istio-ingressgateway` Kubernetes Service

This is a Kubernetes Service.

It provides a stable network endpoint for the ingress gateway Pods.

``` text
Kubernetes Service
istio-ingressgateway
        |
        v
Istio Ingress Gateway Pods
```

## B. Istio `Gateway` resource

Our file:

``` text
kubernetes/base/order-service/gateway.yaml
```

contains:

``` yaml
apiVersion: networking.istio.io/v1
kind: Gateway

metadata:
  name: order-gateway
  namespace: order-dev

spec:
  selector:
    istio: ingressgateway

  servers:
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - "order.local"
```

This is **configuration**, not a Pod and not a Kubernetes Service.

It tells the selected Envoy gateway:

> Accept HTTP traffic on port 80 for host `order.local`.

## C. Istio Ingress Gateway Pod

This is the actual Envoy workload.

So:

``` text
istio-ingressgateway Service
        |
        v
Istio Ingress Gateway Pod
        |
        | selected by
        v
Istio Gateway configuration
```

------------------------------------------------------------------------

# 9. How Does the Istio Gateway Select the Ingress Pod?

Our Gateway has:

``` yaml
selector:
  istio: ingressgateway
```

The ingress gateway Pod has:

``` text
istio=ingressgateway
```

Therefore the Gateway configuration applies to that Envoy workload.

Think of it as:

``` text
Gateway resource
      |
      | selector
      v
istio=ingressgateway
      |
      v
Ingress Envoy Pod
```

------------------------------------------------------------------------

# 10. VirtualService --- What Is It?

The Gateway answers:

> Which incoming traffic should the ingress Envoy accept?

The VirtualService answers:

> Once traffic is accepted, where should it go and what traffic rules
> should apply?

Our VirtualService:

``` yaml
apiVersion: networking.istio.io/v1
kind: VirtualService

metadata:
  name: order-service
  namespace: order-dev

spec:
  hosts:
    - "order.local"

  gateways:
    - order-gateway

  http:
    - timeout: 2s

      retries:
        attempts: 2
        perTryTimeout: 1s
        retryOn: 5xx,connect-failure,reset,refused-stream

      route:
        - destination:
            host: order-service
            port:
              number: 8080
```

It says:

``` text
Host: order.local
       |
       v
Gateway: order-gateway
       |
       v
Order Service
       |
       +--> timeout 2s
       +--> retry policy
       +--> destination port 8080
```

------------------------------------------------------------------------

# 11. Gateway vs VirtualService

A simple memory trick:

``` text
Gateway
   =
"Can this traffic enter?"

VirtualService
   =
"Where should this traffic go and what routing rules apply?"
```

Example:

``` text
Client
  |
  | Host: order.local
  v
Gateway
  |
  | accepted
  v
VirtualService
  |
  | route to order-service:8080
  v
Kubernetes Service
```

------------------------------------------------------------------------

# 12. Kubernetes Service vs VirtualService

Another important interview distinction.

## Kubernetes Service

Example:

``` yaml
kind: Service
```

Its responsibility includes:

-   stable virtual endpoint
-   selecting Pods using labels
-   maintaining endpoints through Kubernetes
-   service discovery through Kubernetes DNS

Example:

``` text
order-service
      |
      +--> Pod A
      +--> Pod B
      +--> Pod C
```

## VirtualService

Its responsibility includes:

-   HTTP routing
-   traffic rules
-   retries
-   timeouts
-   traffic splitting
-   matching hosts/paths/headers

It does **not** select Pods.

### Memory shortcut

``` text
Kubernetes Service
=
"Which workloads provide this service?"

VirtualService
=
"How should requests be routed to this service?"
```

------------------------------------------------------------------------

# 13. How Service Discovery Actually Happens

This is a common interview question.

Suppose VirtualService says:

``` yaml
destination:
  host: order-service
  port:
    number: 8080
```

Does VirtualService itself discover the Pods?

**No.**

The flow is:

``` text
Kubernetes
   |
   +--> Service: order-service
   |
   +--> EndpointSlices
   |
   +--> Pod IPs
   |
   v
istiod observes service/endpoints
   |
   | EDS/xDS
   v
Envoy
   |
   v
Healthy Order Pod
```

Kubernetes maintains the service/endpoints.

Istio observes that information and distributes routing information to
Envoy.

### Important interview answer

> Kubernetes performs the underlying service discovery through Services
> and EndpointSlices. Istio does not replace Kubernetes service
> discovery; istiod consumes that information and distributes endpoint
> information to Envoy using xDS, including EDS.

------------------------------------------------------------------------

# 14. Complete Request Flow

Our current lesson intentionally does not include APIM or NGINX.

``` text
                Client
                  |
                  | HTTP
                  | Host: order.local
                  v
       +------------------------+
       | istio-ingressgateway   |
       | Envoy                  |
       +------------------------+
                  |
                  | Gateway accepts
                  v
       +------------------------+
       | VirtualService         |
       | order-service          |
       +------------------------+
                  |
                  | route
                  v
       +------------------------+
       | Kubernetes Service     |
       | order-service:8080     |
       +------------------------+
                  |
                  v
       +------------------------+
       | Order Pod              |
       |                        |
       | Envoy Sidecar          |
       |       |                |
       |       v                |
       | Spring Boot :8080      |
       +------------------------+
                  |
                  v
             PostgreSQL
```

------------------------------------------------------------------------

# 15. Internal Service-to-Service Communication

For two services:

``` text
Payment Service
      |
      v
Payment Envoy
      |
      | mTLS
      v
Order Envoy
      |
      v
Order Service
```

Traffic does **not** normally go back through the ingress gateway.

The ingress gateway is primarily for traffic entering the mesh.

Internal traffic uses the source and destination workloads' Envoy
proxies.

------------------------------------------------------------------------

# 16. Istio Configuration Distribution

We verified this with:

``` powershell
istioctl proxy-status
```

Example:

``` text
NAME                         ISTIOD       VERSION
order-service-xxxxx          istiod-xxx   1.31.0
istio-ingressgateway-xxxxx   istiod-xxx   1.31.0
```

The proxies subscribe to configuration such as:

``` text
CDS = Cluster Discovery Service
LDS = Listener Discovery Service
EDS = Endpoint Discovery Service
RDS = Route Discovery Service
```

Memory:

``` text
LDS -> listeners
RDS -> routes
CDS -> clusters
EDS -> endpoints
```

The control plane sends configuration.

The Envoys handle actual traffic.

------------------------------------------------------------------------

# 17. Timeout

We configured:

``` yaml
timeout: 2s
```

This means Envoy will wait up to the configured timeout for the upstream
request.

Conceptually:

``` text
Request
  |
  v
Envoy
  |
  |---- wait ----|
  |              |
  0s             2s
                 |
                 v
              timeout
```

It does not mean:

> The Java application will be killed after two seconds.

It means the proxy has a request deadline for the upstream operation.

### Why timeout matters

Without appropriate timeouts, a slow downstream dependency can cause
requests to remain open for too long.

In a microservice system:

``` text
A -> B -> C -> D
```

poor timeout management can create resource exhaustion and cascading
delays.

------------------------------------------------------------------------

# 18. Retries

We configured:

``` yaml
retries:
  attempts: 2
  perTryTimeout: 1s
  retryOn: 5xx,connect-failure,reset,refused-stream
```

Important distinction:

``` text
attempts: 2
```

means **two retries**, not two total attempts.

Therefore:

``` text
Original request
      |
      X 503
      |
      v
Retry #1
      |
      X 503
      |
      v
Retry #2
      |
      X 503
```

Total application invocations:

``` text
1 original + 2 retries = 3
```

We proved this experimentally using a temporary `/test/retry` endpoint.

Application logs showed:

``` text
>>> Retry test endpoint invoked
>>> Retry test endpoint invoked
>>> Retry test endpoint invoked
```

### Production warning

Retries are not automatically safe.

For example:

``` text
POST /orders
```

could create an order.

If the first request actually reached the server but the response was
lost, retrying could potentially create a duplicate operation.

Therefore retries should be designed together with:

-   idempotency
-   appropriate retryable status codes
-   bounded attempts
-   timeouts
-   backoff
-   awareness of side effects

------------------------------------------------------------------------

# 19. mTLS

mTLS means:

> Mutual TLS.

Normal TLS commonly provides server authentication and encryption.

mTLS provides authentication on both sides.

In Istio:

``` text
Service A Envoy
      |
      | encrypted + authenticated
      | mTLS
      v
Service B Envoy
```

The application generally does not need to implement this TLS
communication itself.

------------------------------------------------------------------------

# 20. We Started With PERMISSIVE

Initially:

``` text
Effective PeerAuthentication:
Workload mTLS mode: PERMISSIVE
```

PERMISSIVE allows compatible workloads to communicate using mTLS while
still supporting plaintext where applicable.

This is useful during migration.

------------------------------------------------------------------------

# 21. We Changed to STRICT

We created:

``` text
kubernetes/base/order-service/peerauthentication.yaml
```

with:

``` yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication

metadata:
  name: order-mtls
  namespace: order-dev

spec:
  mtls:
    mode: STRICT
```

Then verified:

``` text
Effective PeerAuthentication:
Workload mTLS mode: STRICT

Applied PeerAuthentication:
order-mtls.order-dev
```

The application continued to work through the Istio ingress path.

------------------------------------------------------------------------

# 22. How We Verified mTLS

We inspected Envoy cluster configuration.

The configuration contained:

``` text
tlsMode: istio
```

and:

``` text
envoy.transport_sockets.tls
```

with TLS configuration and SDS certificate configuration.

We also later saw mTLS directly in telemetry:

``` text
connection_security_policy="mutual_tls"
```

and:

``` text
security_istio_io_tlsMode="istio"
```

This gives us two useful verification approaches:

``` text
Configuration verification
        +
Telemetry verification
        =
Strong evidence of Istio mTLS
```

------------------------------------------------------------------------

# 23. What Is SDS?

SDS stands for:

> Secret Discovery Service.

Envoy needs certificates and keys for mTLS.

Istio manages workload certificates and delivers the required secret
material to Envoy through the SDS mechanism.

Conceptually:

``` text
istiod / Istio CA
       |
       | certificates
       v
     SDS
       |
       v
    Envoy
       |
       | mTLS
       v
Other Envoy
```

You do not normally want application code manually managing these
workload certificates.

------------------------------------------------------------------------

# 24. Observability

Istio can generate telemetry from the proxy layer.

This is useful because the application does not need to implement custom
metrics for every network-level concern.

Our architecture:

``` text
Order Service
     |
     v
Envoy Sidecar
     |
     | /stats/prometheus
     v
Prometheus
     |
     v
PromQL
```

------------------------------------------------------------------------

# 25. Prometheus Setup

We installed Prometheus through Helm:

``` powershell
helm install prometheus prometheus-community/prometheus `
  --namespace monitoring `
  --set alertmanager.enabled=false `
  --set prometheus-pushgateway.enabled=false `
  --set kube-state-metrics.enabled=false `
  --set prometheus-node-exporter.enabled=false
```

The monitoring namespace:

``` text
monitoring
```

Prometheus was then configured using:

``` text
infrastructure/local/prometheus-values.yaml
```

The chart version used in this lesson requires:

``` yaml
extraScrapeConfigs: |
```

rather than a YAML list.

Our relevant configuration was:

``` yaml
extraScrapeConfigs: |
  - job_name: "istio-mesh"
    metrics_path: /stats/prometheus

    kubernetes_sd_configs:
      - role: pod

    relabel_configs:
      - action: keep
        source_labels:
          - __meta_kubernetes_pod_annotation_prometheus_io_scrape
        regex: "true"

      - action: replace
        source_labels:
          - __meta_kubernetes_pod_ip
        target_label: __address__
        replacement: "$1:15020"
```

The important lesson was:

> Always validate Helm rendering before assuming that a values file has
> affected the generated configuration.

We used:

``` powershell
helm template ...
```

to confirm the rendered configuration before relying on it.

------------------------------------------------------------------------

# 26. Why Port 15020?

Istio-injected Pods expose a merged Prometheus metrics endpoint through:

``` text
:15020/stats/prometheus
```

For our Order Service:

``` text
10.1.0.85:15020/stats/prometheus
```

Prometheus successfully discovered and scraped this endpoint.

The direct Envoy statistics endpoint on `15090` is useful for inspecting
Envoy metrics directly, but our Prometheus scrape setup used the Istio
sidecar's merged endpoint on `15020`.

------------------------------------------------------------------------

# 27. Prometheus Target Verification

Prometheus showed:

``` text
istio-mesh
2 / 3 up
```

The important targets were:

``` text
istio-ingressgateway -> UP
order-service         -> UP
istiod                -> DOWN
```

The Order Service target was:

``` text
10.1.0.85:15020/stats/prometheus
```

This proved:

``` text
Pod discovery
      +
Istio metrics endpoint
      +
Prometheus scraping
      =
Working observability pipeline
```

The `istiod` target being DOWN was not required for our application
telemetry exercise. The important application and ingress targets were
UP.

------------------------------------------------------------------------

# 28. Querying Istio Metrics

We queried:

``` promql
istio_requests_total
```

Prometheus returned series containing labels such as:

``` text
destination_workload="order-service"
destination_service="order-service.order-dev.svc.cluster.local"
source_workload="istio-ingressgateway"
response_code="200"
connection_security_policy="mutual_tls"
```

This is powerful because one metric gives us a large amount of
contextual information.

------------------------------------------------------------------------

# 29. Understanding the Metric

Example:

``` text
istio_requests_total{
  source_workload="istio-ingressgateway",
  destination_workload="order-service",
  destination_service="order-service.order-dev.svc.cluster.local",
  response_code="200",
  connection_security_policy="mutual_tls"
}
```

Read it as:

> The Istio ingress gateway sent HTTP traffic to the Order Service, the
> response was HTTP 200, and the connection used mutual TLS.

Another series showed:

``` text
response_code="503"
```

with a value corresponding to the retry experiment.

This connected our practical retry test directly to observability.

------------------------------------------------------------------------

# 30. Why `istio_requests_total` Is Important

It lets us answer questions such as:

-   How many requests reached a service?
-   Which service generated traffic?
-   Which service received it?
-   What HTTP status codes are occurring?
-   Is traffic using mTLS?
-   Which workload is involved?

For example:

``` promql
istio_requests_total{
  destination_workload="order-service"
}
```

can narrow the telemetry to Order Service traffic.

A rate query can be used to calculate request throughput:

``` promql
rate(istio_requests_total[5m])
```

A 5xx-focused query can be used to investigate server errors:

``` promql
rate(
  istio_requests_total{
    destination_workload="order-service",
    response_code=~"5.."
  }[5m]
)
```

These are examples for future observability work; detailed
PromQL/dashboard design is outside the current lesson.

------------------------------------------------------------------------

# 31. Troubleshooting Journey --- What We Actually Faced

This section is intentionally included so that future revision reminds
us of the real problems rather than only the final happy path.

## Problem 1 --- Kubernetes Pod could not connect to PostgreSQL

The application entered:

``` text
CrashLoopBackOff
```

Hibernate could not obtain JDBC metadata.

The investigation showed PostgreSQL had lost its host port mapping.

We checked:

``` powershell
docker inspect enterprise-order-postgres --format '{{json .NetworkSettings.Ports}}'
```

and found no host mapping for `5432`.

We recreated PostgreSQL:

``` powershell
docker compose -f infrastructure/local/docker-compose.yml up -d --force-recreate postgres
```

After that:

``` text
0.0.0.0:5432 -> 5432/tcp
```

and the Kubernetes application recovered.

### Lesson

Always check the network path between the application and its
dependencies.

------------------------------------------------------------------------

# 32. Troubleshooting --- Health Probes and Security

During retry testing we temporarily introduced Spring Security
configuration.

The Pod eventually showed:

``` text
Readiness probe failed: 403
Liveness probe failed: 403
```

The application was healthy, but Kubernetes probes were being rejected.

We explicitly allowed:

``` text
/actuator/health
/actuator/health/**
/test/retry
```

After the correction:

``` text
2/2 Running
0 restarts
```

### Lesson

A Pod can contain a healthy application and still fail Kubernetes health
checks because of application-level security configuration.

------------------------------------------------------------------------

# 33. Troubleshooting --- Slow Startup

The application took approximately 38 seconds to start in one test.

Our liveness probe began relatively early.

This highlighted an important production improvement:

> A slow-starting Java application may benefit from a `startupProbe`.

Conceptually:

``` text
startupProbe
     |
     | application starts
     v
startup succeeds
     |
     +--> readinessProbe
     |
     +--> livenessProbe
```

We did not change this immediately because the application ultimately
stabilized, but it is a production hardening item.

------------------------------------------------------------------------

# 34. Troubleshooting --- Prometheus Configuration

Our first Prometheus configuration attempt did not appear in the
rendered configuration.

We investigated:

``` text
Helm values
   ↓
helm template
   ↓
generated configuration
   ↓
running Prometheus
```

The important discovery was that this chart version expects:

``` yaml
extraScrapeConfigs: |
```

at the root level.

After correcting it, `helm template` showed:

``` text
job_name: "istio-mesh"
metrics_path: /stats/prometheus
replacement: "$1:15020"
```

The running Prometheus then loaded the configuration and discovered:

``` text
order-service -> UP
```

### Lesson

When using Helm:

> Do not assume that accepted values are necessarily rendered values.

Validate with:

``` powershell
helm template
```

and then verify the live resource.

------------------------------------------------------------------------

# 35. Temporary Retry Test

We created a temporary controller:

``` java
@GetMapping("/retry")
@ResponseStatus(HttpStatus.SERVICE_UNAVAILABLE)
public String retryTest() {
    System.out.println(">>> Retry test endpoint invoked");
    return "Temporary failure for retry demonstration";
}
```

The endpoint intentionally returned:

``` text
503 Service Unavailable
```

Istio retried it.

Application logs showed three invocations for one client request.

This was an excellent practical demonstration of why proxy-level retries
can change the number of times an application receives a request.

------------------------------------------------------------------------

# 36. Important Cleanup After This Lesson

The retry controller and its temporary security configuration were
created specifically for the demonstration.

Before considering the application baseline clean, remove the temporary
retry-test code and decide on the permanent application security
configuration.

Keep:

``` text
PeerAuthentication STRICT
```

because mTLS is part of our target architecture.

Review the current VirtualService timeout/retry configuration before
production. The lesson configuration is intentionally educational and
should not automatically be treated as the final production policy.

Also review the Prometheus scrape configuration to avoid duplicate
scraping when moving to a more complete monitoring stack.

------------------------------------------------------------------------

# 37. Common Confusions --- Quick Revision Table

  ------------------------------------------------------------------------
Concept                  What it is              Main responsibility
  ------------------------ ----------------------- -----------------------
Pod                      Kubernetes workload     Runs containers
unit

Deployment               Kubernetes controller   Maintains Pods

Service                  Kubernetes networking   Stable service
object                  endpoint + Pod
selection

EndpointSlice            Kubernetes endpoint     Tracks backend
data                    endpoints

Envoy                    Proxy                   Handles mesh traffic

Istiod                   Istio control plane     Distributes
configuration

Istio Gateway            Istio config resource   Defines accepted
ingress traffic

Istio Ingress Gateway    Envoy workload          Handles incoming mesh
traffic

`istio-ingressgateway`   Kubernetes Service      Exposes/selects ingress
Service                                          gateway Pods

VirtualService           Istio routing resource  Defines request
routing/policies

PeerAuthentication       Istio security resource Controls workload mTLS

Prometheus               Metrics system          Scrapes/stores/query
metrics
  ------------------------------------------------------------------------

------------------------------------------------------------------------

# 38. The Most Important Mental Model

If you remember only one diagram, remember this:

``` text
                         CONTROL PLANE
                       +---------------+
                       |    istiod     |
                       |               |
                       | configuration |
                       +-------+-------+
                               |
                              xDS
                               |
             +-----------------+----------------+
             |                                  |
             v                                  v
      +-------------+                    +-------------+
      | Ingress     |                    | Order Pod   |
      | Envoy       |                    |             |
      |             |                    | Envoy       |
      +------+------+                    |     |       |
             |                           |     v       |
             |                           | Spring Boot |
             |                           +-------------+
             |
             | actual traffic
             v
      Kubernetes Service
             |
             v
        Order Pod


             OBSERVABILITY
                   |
                   v
              Prometheus
                   |
                   v
         istio_requests_total
```

Remember:

``` text
istiod = brain/configuration
Envoy  = traffic/data plane
Service = Kubernetes discovery/network endpoint
Gateway = what ingress Envoy accepts
VirtualService = how traffic is routed
PeerAuthentication = mTLS policy
Prometheus = metrics collection/query
```

------------------------------------------------------------------------

# 39. Production Architecture We Are Building Toward

Our final target is:

``` text
                         Internet / Client
                                |
                                v
                       Microsoft Entra ID
                                |
                                v
                     Azure API Management
                                |
                       authentication /
                       rate limits /
                       policies
                                |
                                v
                         NGINX Ingress
                                |
                                v
                     Istio Ingress Gateway
                                |
                                v
                         VirtualService
                                |
                                v
                    +---------------------+
                    |   Order Service     |
                    |                     |
                    | Envoy + Spring Boot |
                    +----------+----------+
                               |
                               v
                           PostgreSQL


        +---------------------------------------------+
        | Cross-cutting platform capabilities         |
        |                                             |
        | Istio mTLS / retries / timeouts / routing   |
        | Key Vault + Managed Identity                |
        | Application Insights                        |
        | Azure Monitor                              |
        | Log Analytics                              |
        +---------------------------------------------+

        CI/CD:
        Developer -> Git -> Azure DevOps -> Build
                  -> Docker -> ACR -> Helm -> AKS
```

The reason we learned Istio separately first was to avoid mixing:

``` text
APIM
+
NGINX
+
Istio
+
AKS
```

all at once.

------------------------------------------------------------------------

# 40. Interview Questions and Answers

## Q1. What problem does Istio solve?

Istio provides a service mesh layer for traffic management,
service-to-service security, resilience, and observability without
requiring each microservice to implement those networking capabilities
independently.

------------------------------------------------------------------------

## Q2. Is Istio a replacement for Kubernetes?

No.

Kubernetes manages workloads and provides core
networking/service-discovery primitives. Istio adds service-mesh
capabilities on top.

------------------------------------------------------------------------

## Q3. What is the difference between istiod and Envoy?

`istiod` is the Istio control plane that distributes configuration.

Envoy is the data-plane proxy that handles actual application traffic.

------------------------------------------------------------------------

## Q4. Does application traffic pass through istiod?

No.

`istiod` distributes configuration to Envoy. Actual traffic flows
through Envoy proxies.

------------------------------------------------------------------------

## Q5. What is an Istio Gateway?

An Istio Gateway is a configuration resource that defines what traffic
an ingress/egress gateway workload should accept.

It is not the Envoy Pod itself.

------------------------------------------------------------------------

## Q6. What is an Istio Ingress Gateway?

It is the Envoy-based workload that receives traffic entering the
service mesh.

------------------------------------------------------------------------

## Q7. What is a VirtualService?

It defines how requests should be routed after they are accepted by the
relevant gateway or for mesh traffic, including rules such as host/path
matching, destinations, retries, timeouts, and traffic splitting.

------------------------------------------------------------------------

## Q8. Does VirtualService perform Kubernetes service discovery?

No.

Kubernetes Services and EndpointSlices provide the underlying
service-discovery information. Istio consumes that information and
distributes endpoint configuration to Envoy.

------------------------------------------------------------------------

## Q9. Why do we need both Gateway and VirtualService?

They solve different problems.

``` text
Gateway
=
What ingress traffic should be accepted?

VirtualService
=
How should accepted traffic be routed?
```

------------------------------------------------------------------------

## Q10. Why use Envoy sidecars?

They provide a consistent proxy layer where mesh policies such as mTLS,
retries, routing, and telemetry can be applied without embedding all of
that functionality into application code.

------------------------------------------------------------------------

## Q11. What does mTLS provide?

Mutual TLS provides encrypted communication and mutual workload
authentication.

------------------------------------------------------------------------

## Q12. What is the difference between PERMISSIVE and STRICT mTLS?

`PERMISSIVE` can accept both mTLS and plaintext traffic depending on the
configuration and peer.

`STRICT` requires mTLS.

------------------------------------------------------------------------

## Q13. What happens when retries are configured with `attempts: 2`?

There can be:

``` text
1 original attempt + 2 retries = 3 attempts
```

It does not mean two total attempts.

------------------------------------------------------------------------

## Q14. Why can retries be dangerous?

Because retrying a state-changing request can duplicate side effects if
the first request was actually processed.

Idempotency and appropriate retry policy are important.

------------------------------------------------------------------------

## Q15. How does Istio get endpoint information?

Istiod observes Kubernetes service/endpoints information and distributes
endpoint data to Envoy through xDS, including EDS.

------------------------------------------------------------------------

## Q16. What is Prometheus doing in this architecture?

Prometheus scrapes metrics exposed by workloads/proxies and stores them
so they can be queried using PromQL.

------------------------------------------------------------------------

## Q17. What does `istio_requests_total` represent?

It is an Istio request counter containing labels describing request
source, destination, response code, protocol, security policy, and
workload information.

------------------------------------------------------------------------

# 41. Useful Commands From This Lesson

### Check Istio installation

``` powershell
istioctl version
```

### Check Istio Pods

``` powershell
kubectl get pods -n istio-system
```

### Check sidecar injection

``` powershell
kubectl get pods -n order-dev
```

Look for:

``` text
2/2 Running
```

### Check proxy synchronization

``` powershell
istioctl proxy-status
```

### Inspect gateway

``` powershell
kubectl describe gateway order-gateway -n order-dev
```

### Inspect routes

``` powershell
istioctl proxy-config routes -n istio-system <ingress-pod>
```

### Inspect endpoints

``` powershell
istioctl proxy-config endpoints -n istio-system <ingress-pod>
```

### Inspect mTLS configuration

``` powershell
istioctl x describe pod <order-pod> -n order-dev
```

### Check Prometheus targets

``` text
http://localhost:9091/targets
```

### Query Istio requests

``` promql
istio_requests_total
```

### Request rate example

``` promql
rate(istio_requests_total[5m])
```

------------------------------------------------------------------------

# 42. Lesson Completion Checklist

## Istio Fundamentals

-   [x] Why Istio exists
-   [x] Control plane vs data plane
-   [x] istiod
-   [x] Envoy
-   [x] Sidecar injection

## Ingress

-   [x] Istio Ingress Gateway
-   [x] Kubernetes ingress gateway Service
-   [x] Istio Gateway
-   [x] Gateway selector
-   [x] VirtualService
-   [x] Request flow

## Kubernetes Integration

-   [x] Kubernetes Service
-   [x] Endpoint discovery
-   [x] EndpointSlices
-   [x] Kubernetes DNS
-   [x] Istio xDS/EDS relationship

## Traffic Management

-   [x] Timeout
-   [x] Retry policy
-   [x] Practical retry test
-   [x] Retry side-effect warning

## Security

-   [x] PERMISSIVE mTLS
-   [x] STRICT mTLS
-   [x] PeerAuthentication
-   [x] Envoy TLS configuration
-   [x] mTLS telemetry

## Observability

-   [x] Envoy metrics
-   [x] Prometheus installation
-   [x] Prometheus target discovery
-   [x] Istio request metrics
-   [x] `istio_requests_total`

## Troubleshooting

-   [x] PostgreSQL connectivity problem
-   [x] CrashLoopBackOff investigation
-   [x] Health-probe/security interaction
-   [x] Prometheus Helm configuration troubleshooting

------------------------------------------------------------------------

# 43. Final Revision Cheat Sheet

When revising this lesson later, remember this sequence:

``` text
1. Kubernetes runs the application.
             |
2. Service gives it a stable endpoint.
             |
3. Istio injects Envoy.
             |
4. Gateway controls ingress acceptance.
             |
5. VirtualService controls routing.
             |
6. Envoy applies timeout/retry/mTLS.
             |
7. Kubernetes provides service/endpoints.
             |
8. istiod distributes configuration.
             |
9. Prometheus collects telemetry.
```

### One-line definitions

``` text
Kubernetes Service
= stable service endpoint + Pod selection

Istio Gateway
= ingress listener/acceptance configuration

Istio Ingress Gateway
= Envoy workload handling ingress traffic

VirtualService
= request routing rules

Envoy
= data-plane proxy

istiod
= Istio control plane

PeerAuthentication
= workload mTLS policy

Prometheus
= metrics collection and querying
```

------------------------------------------------------------------------

# 44. What We Learned Practically

This lesson was not just configuration.

We proved the concepts through the running platform:

``` text
Sidecar injection
       ↓
Gateway
       ↓
VirtualService
       ↓
Order Service
       ↓
Timeout
       ↓
Retry
       ↓
mTLS STRICT
       ↓
Envoy telemetry
       ↓
Prometheus
```

The most important achievement is that the user can now explain not just
**what** Istio resources are, but **why they exist, how they interact,
and how to verify them in a real Kubernetes environment**.

------------------------------------------------------------------------

# 45. Next Lesson

The next major stage is to continue toward the production architecture
rather than adding unnecessary local complexity.

The remaining platform areas include:

``` text
NGINX Ingress
       ↓
Azure API Management
       ↓
Microsoft Entra ID
       ↓
Azure Key Vault
       ↓
Managed Identity
       ↓
ACR
       ↓
Azure DevOps CI/CD
       ↓
AKS
       ↓
Application Insights
       ↓
Azure Monitor / Log Analytics
```

Before moving to the next lesson, the temporary retry demonstration code
and temporary security configuration should be cleaned up so the
repository returns to a clean application baseline.

------------------------------------------------------------------------

## Lesson 4 Status

**Istio fundamentals, ingress routing, traffic management, mTLS, and
Prometheus-based observability have been implemented and verified
locally.**

**Status: Lesson 4 practical work complete; documentation complete.**

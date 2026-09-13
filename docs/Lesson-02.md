Absolutely. Lesson 2 should document the **complete application containerization journey**, not just the Dockerfile. This will also become useful interview material.

Below is a GitHub-ready `lesson2.md` that you can place at:

```text
docs/lessons/lesson2.md
```

# Lesson 2 — Containerizing the Order Service with Docker

## 1. Objective

In Lesson 1, we installed and verified the local Kubernetes and Istio environment.

In this lesson, we prepared the `order-service` application for containerized execution using Docker.

The goals were:

* Configure Spring Boot to connect to PostgreSQL.
* Run PostgreSQL locally inside Docker.
* Verify the Spring Boot application independently.
* Create a production-oriented multi-stage Docker image.
* Run the Spring Boot application inside a Docker container.
* Connect two containers using a Docker bridge network.
* Understand Docker container-to-container communication.
* Prepare the application for the next stage: Kubernetes deployment.

---

# 2. Architecture Before Dockerization

Initially, the application ran directly on the developer machine.

```text
Developer Machine
│
├── Spring Boot Order Service
│       │
│       │ JDBC
│       ▼
│   PostgreSQL
│   Docker Container
│
└── Docker Desktop Kubernetes
        │
        └── Istio
```

The Spring Boot application was started using Maven:

```powershell
.\mvnw.cmd spring-boot:run
```

The application initially failed because Spring Boot had a PostgreSQL dependency but no datasource configuration.

The error was:

```text
Failed to configure a DataSource:
'url' attribute is not specified
```

This demonstrated that adding the PostgreSQL JDBC dependency alone is not enough. Spring Boot also needs the datasource connection details.

---

# 3. Local PostgreSQL Infrastructure

Instead of installing PostgreSQL directly on Windows, PostgreSQL was run using Docker.

The infrastructure location is:

```text
infrastructure/
└── local/
    └── docker-compose.yml
```

The Docker Compose configuration is:

```yaml
services:

  postgres:
    image: postgres:17-alpine
    container_name: enterprise-order-postgres

    environment:
      POSTGRES_DB: orderdb
      POSTGRES_USER: orderapp
      POSTGRES_PASSWORD: orderapp_local_password

    ports:
      - "5432:5432"

    volumes:
      - postgres_data:/var/lib/postgresql/data

    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U orderapp -d orderdb"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
```

---

# 4. Starting PostgreSQL

From:

```text
infrastructure/local
```

we started PostgreSQL using:

```powershell
docker compose up -d
```

Verification:

```powershell
docker ps
```

The PostgreSQL container reported:

```text
enterprise-order-postgres
postgres:17-alpine
Up (healthy)
```

The health check is important because it confirms that PostgreSQL is actually accepting connections rather than merely having a running container.

---

# 5. Spring Boot Database Configuration

The application uses:

```text
services/order-service/src/main/resources/application.yaml
```

Configuration:

```yaml
spring:
  application:
    name: order-service

  datasource:
    url: ${SPRING_DATASOURCE_URL}
    username: ${SPRING_DATASOURCE_USERNAME}
    password: ${SPRING_DATASOURCE_PASSWORD}

  jpa:
    hibernate:
      ddl-auto: none
    open-in-view: false

server:
  port: 8080
```

## Why environment variables?

Database credentials should not be hard-coded into application configuration.

Instead of:

```yaml
password: orderapp_local_password
```

we use:

```yaml
password: ${SPRING_DATASOURCE_PASSWORD}
```

This allows the same application artifact to run in different environments.

For example:

```text
Local
   ↓
Environment Variables

Docker
   ↓
Container Environment Variables

Kubernetes
   ↓
Kubernetes Secrets

Azure
   ↓
Key Vault / Managed Identity
```

This separation between **application artifact** and **environment configuration** is an important production practice.

---

# 6. Why `ddl-auto: none`?

We deliberately configured:

```yaml
ddl-auto: none
```

We do not want Hibernate automatically creating or modifying database schemas in a production-oriented application.

Later we will introduce **Flyway database migrations**.

The intended model will be:

```text
Application
     │
     ▼
Flyway Migration
     │
     ▼
PostgreSQL Schema
```

This gives us version-controlled and repeatable database changes.

---

# 7. Verifying Spring Boot Without Docker

After configuring the datasource environment variables, the application was started using:

```powershell
$env:SPRING_DATASOURCE_URL="jdbc:postgresql://localhost:5432/orderdb"
$env:SPRING_DATASOURCE_USERNAME="orderapp"
$env:SPRING_DATASOURCE_PASSWORD="orderapp_local_password"
```

Then:

```powershell
.\mvnw.cmd spring-boot:run
```

The application successfully started:

```text
Started OrderServiceApplication
```

This verified:

```text
Spring Boot
    │
    │ JDBC
    ▼
PostgreSQL Docker Container
```

---

# 8. Why Dockerize the Application?

Before containerization:

```text
Windows
│
├── Java 17
├── Maven
├── Spring Boot
└── PostgreSQL Container
```

This works on the developer machine but is less portable.

After containerization:

```text
Docker
│
├── Order Service Container
│       └── Java 17 + Spring Boot
│
└── PostgreSQL Container
        └── PostgreSQL
```

The application now has a consistent runtime environment.

This is the foundation for:

* Kubernetes
* AKS
* CI/CD
* Container registries
* Helm
* Istio

---

# 9. Docker Image Design

We created:

```text
services/order-service/
├── Dockerfile
└── .dockerignore
```

The Dockerfile uses a **multi-stage build**.

---

# 10. Multi-Stage Docker Build

The Dockerfile:

```dockerfile
# =========================
# Stage 1: Build
# =========================
FROM maven:3.9.11-eclipse-temurin-17 AS builder

WORKDIR /app

COPY pom.xml .
COPY .mvn .mvn
COPY mvnw mvnw.cmd ./

RUN chmod +x mvnw

COPY src src

RUN ./mvnw clean package -DskipTests


# =========================
# Stage 2: Runtime
# =========================
FROM eclipse-temurin:17-jre

WORKDIR /app

COPY --from=builder /app/target/*.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
```

---

# 11. Why Multi-Stage Builds?

There are two stages.

## Stage 1 — Build

```text
Maven + JDK 17
       │
       ▼
Compile source code
       │
       ▼
Generate JAR
```

The build environment contains:

* Maven
* JDK
* Source code
* Build dependencies

These are required only during the build.

## Stage 2 — Runtime

```text
JRE 17
   │
   ▼
app.jar
```

The final image does not need:

* Maven
* Java source code
* Build tools

This reduces unnecessary content in the runtime image.

---

# 12. Docker Image

We built:

```powershell
docker build -t order-service:0.1.0 .
```

The resulting image was verified with:

```powershell
docker images order-service
```

Result:

```text
REPOSITORY      TAG       IMAGE ID
order-service   0.1.0     a03d288028f6
```

Image size:

```text
372 MB
```

For the initial implementation, this is acceptable.

Image optimization can be considered later after functionality and architecture are stable.

---

# 13. `.dockerignore`

We created:

```text
target/
.git/
.gitignore
.idea/
*.iml
.vscode/
*.log
.env
.env.*
README.md
```

The purpose is to prevent unnecessary files from being sent to the Docker build context.

For example:

```text
target/
```

is excluded because the Docker build itself creates the JAR.

Similarly:

```text
.idea/
```

contains IDE-specific files and should never be part of the application image.

---

# 14. Docker Networking

A key issue appeared when moving the application into Docker.

From the host machine we used:

```text
localhost:5432
```

But inside the Order Service container:

```text
localhost
```

means:

```text
Order Service container itself
```

It does **not** mean the PostgreSQL container.

Therefore this would be incorrect inside the container:

```text
jdbc:postgresql://localhost:5432/orderdb
```

---

# 15. Dedicated Docker Network

We created a dedicated Docker bridge network:

```powershell
docker network create enterprise-order-network
```

Then connected PostgreSQL:

```powershell
docker network connect enterprise-order-network enterprise-order-postgres
```

The resulting network architecture became:

```text
enterprise-order-network
│
├── enterprise-order-service
│
└── enterprise-order-postgres
```

---

# 16. Docker DNS

Docker provides internal DNS for containers on the same user-defined network.

Therefore, instead of using:

```text
172.19.0.2
```

we use the container name:

```text
enterprise-order-postgres
```

The connection becomes:

```text
jdbc:postgresql://enterprise-order-postgres:5432/orderdb
```

This is better than using the IP address because container IP addresses can change.

The logical flow is:

```text
Order Service
      │
      │ Docker DNS
      ▼
enterprise-order-postgres
      │
      ▼
PostgreSQL :5432
```

---

# 17. Running the Application Container

The application was started using:

```powershell
docker run -d `
  --name enterprise-order-service `
  --network enterprise-order-network `
  -p 8080:8080 `
  -e SPRING_DATASOURCE_URL="jdbc:postgresql://enterprise-order-postgres:5432/orderdb" `
  -e SPRING_DATASOURCE_USERNAME="orderapp" `
  -e SPRING_DATASOURCE_PASSWORD="orderapp_local_password" `
  order-service:0.1.0
```

---

# 18. Understanding the Docker Run Command

### Container name

```text
--name enterprise-order-service
```

Provides a predictable container name.

### Network

```text
--network enterprise-order-network
```

Connects the application to the PostgreSQL network.

### Port mapping

```text
-p 8080:8080
```

Means:

```text
Host port 8080
       ↓
Container port 8080
```

Therefore:

```text
http://localhost:8080
```

can reach the application.

### Environment variables

```text
-e SPRING_DATASOURCE_URL=...
-e SPRING_DATASOURCE_USERNAME=...
-e SPRING_DATASOURCE_PASSWORD=...
```

These provide runtime configuration without modifying the Docker image.

---

# 19. Final Local Docker Architecture

At the end of Lesson 2:

```text
                    Windows Host
                         │
                         │ localhost:8080
                         ▼
              ┌──────────────────────┐
              │ Order Service        │
              │ Docker Container     │
              │                      │
              │ Spring Boot          │
              │ Java 17              │
              │ Port 8080            │
              └──────────┬───────────┘
                         │
                         │ Docker DNS
                         │
                         ▼
              ┌──────────────────────┐
              │ PostgreSQL           │
              │ Docker Container     │
              │                      │
              │ Database: orderdb    │
              │ Port: 5432           │
              └──────────────────────┘
```

Both containers communicate through:

```text
enterprise-order-network
```

---

# 20. Current Container Status

The final `docker ps` showed:

```text
enterprise-order-service
    order-service:0.1.0
    0.0.0.0:8080->8080/tcp
    Up

enterprise-order-postgres
    postgres:17-alpine
    0.0.0.0:5432->5432/tcp
    Up (healthy)
```

This confirms that both application and database containers are running.

---

# 21. What We Learned

## Docker Image vs Container

An **image** is a packaged application/runtime template.

```text
order-service:0.1.0
```

A **container** is a running instance of that image.

```text
enterprise-order-service
```

Conceptually:

```text
Image
  │
  │ docker run
  ▼
Container
```

---

## `localhost` inside containers

A very important Docker concept:

```text
localhost
```

always refers to the current container/process environment.

Therefore:

```text
Order Service Container
localhost:5432
```

does not automatically point to PostgreSQL.

Docker networking solves this using service/container DNS.

---

# 22. Why We Didn't Put Credentials in the Dockerfile

Bad practice:

```dockerfile
ENV SPRING_DATASOURCE_PASSWORD=...
```

Why?

Because Docker image metadata/layers can expose configuration that should remain secret.

Instead:

```text
Docker Image
     │
     │ runtime configuration
     ▼
Environment Variables
```

Later in Kubernetes:

```text
Kubernetes Secret
        │
        ▼
Order Service Pod
```

And eventually in Azure:

```text
Azure Key Vault
        │
        ▼
Managed Identity
        │
        ▼
Order Service
```

---

# 23. Important Production Consideration

The password currently used in local Docker Compose:

```text
orderapp_local_password
```

is only for the local learning environment.

It should **not** become a production credential or be committed as a real secret.

Our future production architecture will use Azure-native secret management.

Planned:

```text
AKS
 │
 ├── Managed Identity
 │
 └── Azure Key Vault
          │
          └── Database credentials/secrets
```

---

# 24. What We Have Completed

| Area                             | Status |
| -------------------------------- | ------ |
| Spring Boot application          | ✅      |
| Java 17                          | ✅      |
| PostgreSQL                       | ✅      |
| PostgreSQL Docker container      | ✅      |
| Spring → PostgreSQL connectivity | ✅      |
| `application.yaml`               | ✅      |
| Environment-based configuration  | ✅      |
| Dockerfile                       | ✅      |
| Multi-stage Docker build         | ✅      |
| Docker image                     | ✅      |
| Docker network                   | ✅      |
| Container-to-container DNS       | ✅      |
| Order Service Docker container   | ✅      |
| PostgreSQL Docker container      | ✅      |
| Istio installed                  | ✅      |

---

# 25. Current Repository Structure

At this stage, the relevant structure is:

```text
enterprise-order-platform/
│
├── architecture/
│
├── docs/
│   └── lessons/
│       ├── lesson1.md
│       └── lesson2.md
│
├── infrastructure/
│   └── local/
│       └── docker-compose.yml
│
├── services/
│   └── order-service/
│       ├── .mvn/
│       ├── src/
│       │   └── main/
│       │       └── resources/
│       │           └── application.yaml
│       │
│       ├── Dockerfile
│       ├── .dockerignore
│       ├── pom.xml
│       ├── mvnw
│       └── mvnw.cmd
│
├── kubernetes/
├── helm/
├── pipelines/
├── scripts/
│
├── .gitignore
└── README.md
```

Empty directories should remain empty until we actually need them.

---

# 26. Interview Questions From Lesson 2

### Q1. Why use a multi-stage Docker build?

To separate the build environment from the runtime environment and avoid shipping unnecessary build tools/source code in the final image.

### Q2. Why shouldn't the application use `localhost` to connect to PostgreSQL when both run in separate containers?

Because `localhost` inside the application container refers to the application container itself.

### Q3. How do Docker containers communicate?

Containers attached to the same user-defined Docker network can communicate using Docker's internal DNS and container/service names.

### Q4. Why use container names instead of container IP addresses?

Container IP addresses can change. Docker DNS provides stable name-based service discovery.

### Q5. Why should database credentials not be baked into the Docker image?

Images can be stored, copied, inspected and pushed to registries. Secrets should be supplied at runtime through a secure configuration mechanism.

### Q6. What does `-p 8080:8080` mean?

It maps host port `8080` to container port `8080`.

### Q7. Difference between Docker image and container?

An image is an immutable packaged template; a container is a running instance of that image.

### Q8. Why use `ddl-auto: none`?

To prevent Hibernate from automatically modifying database schemas. Schema evolution will later be managed through controlled database migrations such as Flyway.

---

# 27. Production Evolution

Our local architecture:

```text
Docker
│
├── Order Service
└── PostgreSQL
```

will eventually evolve into:

```text
                    Microsoft Entra ID
                           │
                           ▼
                    Azure API Management
                           │
                           ▼
                    NGINX Ingress
                           │
                           ▼
                 Istio Ingress Gateway
                           │
                           ▼
                  Order Service Pod
                    │           │
                    │           └── Key Vault
                    │
                    ▼
            Azure PostgreSQL
```

And the deployment pipeline will become:

```text
Developer
    │
    ▼
GitHub
    │
    ▼
Azure DevOps
    │
    ├── Build
    ├── Test
    ├── Docker Build
    └── Push
          │
          ▼
        ACR
          │
          ▼
         AKS
          │
          ▼
        Helm
          │
          ▼
   Order Service Pods
```

This is the reason we are deliberately building the project layer by layer rather than jumping directly into AKS.

---

# 28. Lesson 2 Completion Criteria

Lesson 2 is considered complete when we have verified:

```text
Spring Boot
     ↓
PostgreSQL
     ↓
Docker Image
     ↓
Docker Container
     ↓
Docker Network
     ↓
Container-to-container communication
```

The application container is currently running successfully.

**One final verification remains:** test the application endpoint through `localhost:8080` and confirm the Actuator health response. After that, Lesson 2 can be committed and we can begin **Lesson 3: Kubernetes Deployment of Order Service**.

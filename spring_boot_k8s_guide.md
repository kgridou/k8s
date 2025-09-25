# Spring Boot + Maven + Kubernetes Local Setup Guide

## Prerequisites

1. **Java 17+** installed
2. **Maven 3.6+** installed
3. **Docker** installed and running
4. **Kubernetes cluster** running locally:
   - **Docker Desktop** (easiest - enables Kubernetes in settings)
   - **minikube** (`brew install minikube` or download from minikube.sigs.k8s.io)
   - **kind** (`brew install kind` or `go install sigs.k8s.io/kind@latest`)
5. **kubectl** installed (`brew install kubectl` or via Docker Desktop)

## Step 1: Create Spring Boot Application

### Initialize the project:
```bash
mvn archetype:generate \
  -DgroupId=com.example \
  -DartifactId=demo-app \
  -DarchetypeArtifactId=maven-archetype-quickstart \
  -DinteractiveMode=false

cd demo-app
```

### Update `pom.xml`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <groupId>com.example</groupId>
    <artifactId>demo-app</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>
    
    <name>demo-app</name>
    <description>Demo Spring Boot application</description>
    
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.0</version>
        <relativePath/>
    </parent>
    
    <properties>
        <java.version>17</java.version>
    </properties>
    
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>
    
    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
```

### Create main application class:
Create `src/main/java/com/example/DemoApplication.java`:
```java
package com.example;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
@RestController
public class DemoApplication {
    
    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
    }
    
    @GetMapping("/")
    public String hello() {
        return "Hello from Spring Boot on Kubernetes!";
    }
    
    @GetMapping("/health")
    public String health() {
        return "Application is healthy!";
    }
}
```

### Create `application.yml`:
Create `src/main/resources/application.yml`:
```yaml
server:
  port: 8080

management:
  endpoints:
    web:
      exposure:
        include: health,info
  endpoint:
    health:
      show-details: always
```

## Step 2: Create Dockerfile

Create `Dockerfile` in project root:
```dockerfile
# Note: Single-stage build (not recommended for production)
FROM eclipse-temurin:17-jdk-alpine

# Set working directory
WORKDIR /app

# Copy Maven wrapper and pom.xml
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# Download dependencies
RUN ./mvnw dependency:go-offline -B

# Copy source code
COPY src src

# Build application
RUN ./mvnw clean package -DskipTests

# Expose port
EXPOSE 8080

# Run the application
ENTRYPOINT ["java", "-jar", "target/demo-app-1.0.0.jar"]
```

### Multi-stage Dockerfile (recommended):
```dockerfile
# Build stage
FROM eclipse-temurin:17-jdk-alpine AS build
WORKDIR /app
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .
RUN ./mvnw dependency:go-offline -B
COPY src src
RUN ./mvnw clean package -DskipTests

# Runtime stage
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=build /app/target/demo-app-1.0.0.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

**Important:** Use Eclipse Temurin base images instead of the deprecated `openjdk` images. The old `openjdk:17-jre-alpine` image is no longer available and will cause build failures.

## Step 3: Build and Test Docker Image

```bash
# Build the image
docker build -t demo-app:1.0.0 .

# Test locally
docker run -p 8080:8080 demo-app:1.0.0

# Test the endpoint
curl http://localhost:8080
```

## Step 4: Set up Local Kubernetes

### Option A: Docker Desktop
1. Open Docker Desktop
2. Go to Settings → Kubernetes
3. Check "Enable Kubernetes"
4. Apply & Restart

### Option B: minikube
```bash
# Start minikube
minikube start

# Configure Docker to use minikube's Docker daemon
eval $(minikube docker-env)

# Build image in minikube
docker build -t demo-app:1.0.0 .
```

### Option C: kind
```bash
# Create cluster
kind create cluster --name demo-cluster

# Load image into kind
kind load docker-image demo-app:1.0.0 --name demo-cluster
```

## Step 5: Create Kubernetes Manifests

Create `k8s/` directory and add the following files:

### `k8s/namespace.yaml`:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: demo-app
```

### `k8s/deployment.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
  namespace: demo-app
  labels:
    app: demo-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
    spec:
      containers:
      - name: demo-app
        image: demo-app:1.0.0
        imagePullPolicy: IfNotPresent  # Important for local images
        ports:
        - containerPort: 8080
        env:
        - name: SPRING_PROFILES_ACTIVE
          value: "kubernetes"
        livenessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
```

### `k8s/service.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: demo-app-service
  namespace: demo-app
  labels:
    app: demo-app
spec:
  selector:
    app: demo-app
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
  type: ClusterIP
```

### `k8s/ingress.yaml` (optional):
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo-app-ingress
  namespace: demo-app
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: demo-app.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: demo-app-service
            port:
              number: 80
```

## Step 6: Deploy to Kubernetes

```bash
# Apply all manifests
kubectl apply -f k8s/

# Check deployment status
kubectl get all -n demo-app

# Check pods are running
kubectl get pods -n demo-app

# View logs
kubectl logs -f deployment/demo-app -n demo-app
```

## Step 7: Access the Application

### Option 1: Port Forward (simplest)
```bash
kubectl port-forward service/demo-app-service 8080:80 -n demo-app

# Access at http://localhost:8080
curl http://localhost:8080
```

### Option 2: minikube service (if using minikube)
```bash
minikube service demo-app-service -n demo-app
```

### Option 3: Load Balancer (if using Docker Desktop)
Update service type to `LoadBalancer` in `k8s/service.yaml`:
```yaml
spec:
  type: LoadBalancer
```

## Development Workflow

### 1. Make code changes
### 2. Rebuild and redeploy:
```bash
# Build new image
docker build -t demo-app:1.0.1 .

# Update deployment
kubectl set image deployment/demo-app demo-app=demo-app:1.0.1 -n demo-app

# Or if using minikube, rebuild in minikube context:
eval $(minikube docker-env)
docker build -t demo-app:1.0.1 .
kubectl set image deployment/demo-app demo-app=demo-app:1.0.1 -n demo-app
```

### 3. Alternative: Use Skaffold for automated workflow
Install Skaffold and create `skaffold.yaml`:
```yaml
apiVersion: skaffold/v2beta24
kind: Config
build:
  artifacts:
  - image: demo-app
    docker:
      dockerfile: Dockerfile
deploy:
  kubectl:
    manifests:
    - k8s/*.yaml
```

Then run:
```bash
skaffold dev
```

## Useful Commands

```bash
# Check cluster info
kubectl cluster-info

# View all resources in namespace
kubectl get all -n demo-app

# Describe deployment
kubectl describe deployment demo-app -n demo-app

# View logs
kubectl logs -f deployment/demo-app -n demo-app

# Execute into pod
kubectl exec -it deployment/demo-app -n demo-app -- /bin/sh

# Delete everything
kubectl delete namespace demo-app

# Scale deployment
kubectl scale deployment demo-app --replicas=3 -n demo-app
```

## Troubleshooting

### Common Issues:

1. **Docker Build Failures**: 
   - Error: `openjdk:17-jre-alpine: not found` → Use `eclipse-temurin:17-jre-alpine`
   - Always use Eclipse Temurin images instead of deprecated OpenJDK images

2. **ImagePullBackOff**: 
   - Ensure `imagePullPolicy: IfNotPresent` and image exists locally
   - For minikube: Use `eval $(minikube docker-env)` before building
   - For kind: Use `kind load docker-image <image-name> --name <cluster-name>`

3. **CrashLoopBackOff**: 
   - Check logs with `kubectl logs deployment/demo-app -n demo-app`
   - Verify health endpoints are responding at `/actuator/health`

4. **Port conflicts**: Ensure ports aren't already in use

5. **Resource limits**: Adjust memory/CPU limits if pods are killed

6. **Deployment Order Issues**:
   - Apply namespace first: `kubectl apply -f k8s/namespace.yaml`
   - Then apply other manifests individually to avoid race conditions

### Health Checks:
```bash
# Check if Spring Boot actuator is working
kubectl port-forward service/demo-app-service 8080:80 -n demo-app
curl http://localhost:8080/actuator/health

# Debug deployment issues
kubectl get events -n demo-app --sort-by='.lastTimestamp'
kubectl describe pods -n demo-app
kubectl logs deployment/demo-app -n demo-app --tail=50
```

### Additional Resources:
- **GitHub Actions**: This project includes automated CI/CD pipelines for minikube and kind deployments
- **Enhanced Debugging**: Workflows include comprehensive error handling and debugging output
- **Modern Docker Images**: Updated to use Eclipse Temurin for reliable builds

This setup gives you a complete Spring Boot application running on local Kubernetes with proper health checks, resource management, automated CI/CD, and robust troubleshooting capabilities.
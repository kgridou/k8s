# Spring Boot Kubernetes Demo

A complete demonstration of deploying a Spring Boot application to Kubernetes using Docker, with support for local development environments including minikube and kind.

## 🚀 Quick Start

### Prerequisites

- **Java 17+**
- **Maven 3.6+** 
- **Docker**
- **Kubernetes cluster** (Docker Desktop, minikube, or kind)
- **kubectl**

### Local Development

1. **Clone and build:**
   ```bash
   git clone <repository-url>
   cd k8s
   ./mvnw clean package
   ```

2. **Run locally:**
   ```bash
   ./mvnw spring-boot:run
   # Access at http://localhost:8080
   ```

3. **Test endpoints:**
   ```bash
   curl http://localhost:8080/                    # Hello message
   curl http://localhost:8080/health             # Custom health check
   curl http://localhost:8080/actuator/health    # Spring Boot Actuator
   ```

## 🐳 Docker Deployment

### Build Docker Image
```bash
docker build -t demo-app:1.0.0 .
```

### Run with Docker
```bash
docker run -p 8080:8080 demo-app:1.0.0
```

## ☸️ Kubernetes Deployment

### Deploy to Kubernetes
```bash
# Apply all manifests
kubectl apply -f k8s/

# Check status
kubectl get all -n demo-app

# Access via port forwarding
kubectl port-forward service/demo-app-service 8080:80 -n demo-app
```

### Local Kubernetes Options

#### Option 1: Docker Desktop
1. Enable Kubernetes in Docker Desktop settings
2. Deploy directly with `kubectl apply -f k8s/`

#### Option 2: minikube
```bash
# Start minikube
minikube start

# Build image in minikube
eval $(minikube docker-env)
docker build -t demo-app:1.0.0 .

# Deploy
kubectl apply -f k8s/

# Access service
minikube service demo-app-service -n demo-app
```

#### Option 3: kind
```bash
# Create cluster
kind create cluster --name demo-cluster

# Load image
kind load docker-image demo-app:1.0.0 --name demo-cluster

# Deploy
kubectl apply -f k8s/
```

## 🔧 Project Structure

```
├── src/
│   └── main/
│       ├── java/com/example/
│       │   └── DemoApplication.java          # Main Spring Boot application
│       └── resources/
│           └── application.yml               # Application configuration
├── k8s/
│   ├── namespace.yaml                        # Kubernetes namespace
│   ├── deployment.yaml                       # Application deployment
│   ├── service.yaml                          # Service definition
│   └── ingress.yaml                          # Optional ingress
├── .github/workflows/
│   ├── minikube-deploy.yml                   # CI/CD for minikube
│   └── kind-deploy.yml                       # CI/CD for kind
├── Dockerfile                                # Multi-stage Docker build
├── pom.xml                                   # Maven configuration
└── README.md                                 # This file
```

## 🛠️ Available Commands

### Maven Commands
```bash
# Build application
./mvnw clean package

# Run locally  
./mvnw spring-boot:run

# Run tests
./mvnw test

# Skip tests
./mvnw clean package -DskipTests
```

### Docker Commands
```bash
# Build image
docker build -t demo-app:1.0.0 .

# Run container
docker run -p 8080:8080 demo-app:1.0.0

# For minikube (use minikube's Docker daemon)
eval $(minikube docker-env)
docker build -t demo-app:1.0.0 .
```

### Kubernetes Commands
```bash
# Deploy all resources
kubectl apply -f k8s/

# Check deployment status
kubectl get all -n demo-app

# View logs
kubectl logs -f deployment/demo-app -n demo-app

# Port forward to access service
kubectl port-forward service/demo-app-service 8080:80 -n demo-app

# Scale deployment
kubectl scale deployment demo-app --replicas=3 -n demo-app

# Update image
kubectl set image deployment/demo-app demo-app=demo-app:1.0.1 -n demo-app

# Delete all resources
kubectl delete namespace demo-app
```

## 📋 API Endpoints

| Endpoint | Description | Response |
|----------|-------------|----------|
| `GET /` | Main application endpoint | `Hello from Spring Boot on Kubernetes!` |
| `GET /health` | Custom health check | `Application is healthy!` |
| `GET /actuator/health` | Spring Boot health endpoint | JSON health status |

## 🧪 CI/CD Pipelines

This project includes GitHub Actions workflows for automated testing and deployment with enhanced debugging and error handling:

### Minikube Pipeline (`.github/workflows/minikube-deploy.yml`)
- Builds application with Maven and Java 17 (Eclipse Temurin)
- Sets up minikube cluster (v1.32.0 with Kubernetes v1.28.0)
- Builds Docker image using minikube's Docker daemon
- Deploys to Kubernetes with proper manifest ordering
- Tests all endpoints with retry logic
- Provides detailed debugging output on failures
- Cleans up resources

### Kind Pipeline (`.github/workflows/kind-deploy.yml`)
- Builds application with Maven and Java 17 (Eclipse Temurin)
- Creates Kind cluster with kubectl v1.28.0
- Builds and loads Docker image into Kind cluster
- Deploys with enhanced error handling and debugging
- Tests both external and internal cluster communication
- Verifies image loading into cluster nodes
- Cleans up resources

**Enhanced Features:**
- **Robust error handling**: Detailed pod descriptions and logs on failures
- **Retry logic**: Endpoint testing with 3 attempts and proper wait times
- **Better debugging**: Event logs, resource status, and image verification
- **Proper deployment order**: Namespace creation first, then individual manifests

Both pipelines run on push/PR to main/master branches and include comprehensive logging for troubleshooting.

## 🏗️ Architecture

### Application Architecture
- **Spring Boot 3.2.0** with Java 17
- **Embedded Tomcat** web server
- **Spring Boot Actuator** for health checks and monitoring
- **RESTful API** with custom and actuator endpoints

### Kubernetes Architecture
- **Namespace isolation** (`demo-app` namespace)
- **Multi-replica deployment** (default: 2 replicas)
- **Health probes** (liveness and readiness)
- **Resource limits** (CPU: 500m, Memory: 512Mi)
- **ClusterIP service** with optional ingress

### Docker Architecture
- **Multi-stage build** for optimized image size
- **Build stage**: Eclipse Temurin 17 JDK Alpine for compilation
- **Runtime stage**: Eclipse Temurin 17 JRE Alpine for execution
- **Minimal attack surface** with JRE-only runtime
- **Modern base images**: Uses actively maintained Eclipse Temurin instead of deprecated OpenJDK images

## 🚨 Troubleshooting

### Common Issues

1. **ImagePullBackOff**
   - Ensure `imagePullPolicy: IfNotPresent` for local images
   - Verify image exists in cluster (minikube/kind)
   - For minikube: Use `eval $(minikube docker-env)` before building
   - For kind: Use `kind load docker-image <image-name> --name <cluster-name>`

2. **CrashLoopBackOff**
   - Check application logs: `kubectl logs deployment/demo-app -n demo-app`
   - Verify health check endpoints are responding at `/actuator/health`
   - Check resource limits and startup time

3. **Docker Build Issues**
   - **Old OpenJDK images**: Use `eclipse-temurin:17-jdk-alpine` and `eclipse-temurin:17-jre-alpine`
   - **Base image not found**: Ensure using actively maintained images

4. **GitHub Actions Failures**
   - **Deployment order**: Namespace must be created before other resources
   - **Image loading**: Verify image is properly loaded into cluster
   - **Port forwarding**: Allow sufficient time for application startup (15+ seconds)

5. **Port conflicts**
   - Use different port: `./mvnw spring-boot:run -Dspring-boot.run.arguments="--server.port=8081"`

6. **Resource limits**
   - Adjust CPU/memory limits in `k8s/deployment.yaml`
   - Default limits: CPU 500m, Memory 512Mi

### Health Checks
```bash
# Test health endpoints
curl http://localhost:8080/actuator/health
kubectl port-forward service/demo-app-service 8080:80 -n demo-app
```

## 📚 Additional Resources

- [Spring Boot Documentation](https://spring.io/projects/spring-boot)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Documentation](https://docs.docker.com/)
- [Complete Setup Guide](spring_boot_k8s_guide.md) - Detailed step-by-step instructions

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test locally and with CI/CD pipelines
5. Submit a pull request

## 📄 License

This project is provided as a demonstration and learning resource.
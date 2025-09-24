# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains a comprehensive Spring Boot + Kubernetes deployment guide and reference implementation. The primary focus is on demonstrating local Kubernetes development workflows with Spring Boot applications.

## Key Commands

### Maven/Spring Boot Commands
```bash
# Build the application
mvn clean package

# Run locally (requires Java 17+)
mvn spring-boot:run

# Run tests
mvn test

# Skip tests during build
mvn clean package -DskipTests
```

### Docker Commands
```bash
# Build Docker image
docker build -t demo-app:1.0.0 .

# Test locally with Docker
docker run -p 8080:8080 demo-app:1.0.0

# For minikube development
eval $(minikube docker-env)
docker build -t demo-app:1.0.0 .
```

### Kubernetes Commands
```bash
# Deploy all manifests
kubectl apply -f k8s/

# Check deployment status
kubectl get all -n demo-app

# View application logs
kubectl logs -f deployment/demo-app -n demo-app

# Access application via port forwarding
kubectl port-forward service/demo-app-service 8080:80 -n demo-app

# Update deployment with new image
kubectl set image deployment/demo-app demo-app=demo-app:1.0.1 -n demo-app

# Scale deployment
kubectl scale deployment demo-app --replicas=3 -n demo-app

# Clean up
kubectl delete namespace demo-app
```

### Development Workflow
```bash
# For minikube users - configure Docker environment
eval $(minikube docker-env)

# Complete rebuild and redeploy cycle
docker build -t demo-app:1.0.1 .
kubectl set image deployment/demo-app demo-app=demo-app:1.0.1 -n demo-app
```

## Architecture

### Project Structure
- **Root directory**: Contains the comprehensive Spring Boot + K8s guide (`spring_boot_k8s_guide.md`)
- **Standard Maven layout**: Following `src/main/java` and `src/main/resources` structure
- **Kubernetes manifests**: Located in `k8s/` directory with separate files for namespace, deployment, service, and optional ingress
- **Multi-stage Dockerfile**: Optimized for production with separate build and runtime stages

### Key Components
- **Spring Boot 3.2.0** with Java 17
- **Spring Boot Actuator** for health checks and monitoring
- **Kubernetes-ready configuration** with proper health probes
- **Multi-environment support** through Spring profiles

### Deployment Architecture
- **Namespace isolation**: Uses `demo-app` namespace
- **Multi-replica deployment**: Default 2 replicas for high availability
- **Health checks**: Both liveness and readiness probes configured
- **Resource management**: CPU and memory limits defined
- **Service exposure**: ClusterIP service with optional ingress

## Local Kubernetes Setup Options

The guide supports three local Kubernetes environments:
1. **Docker Desktop**: Simplest setup, enable in Docker Desktop settings
2. **minikube**: Requires `eval $(minikube docker-env)` for local images
3. **kind**: Requires `kind load docker-image` for local images

## Development Notes

- Use `imagePullPolicy: IfNotPresent` for local development images
- Spring Boot Actuator endpoints are exposed at `/actuator/health`
- Default application port is 8080
- Resource requests/limits are configured for development workloads
- Supports both single-stage and multi-stage Dockerfiles
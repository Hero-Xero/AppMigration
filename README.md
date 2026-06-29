# AppMigration: GitOps Deployment Auditing API

AppMigration is a cloud-native, Spring Boot microservice designed to audit and track DevOps metrics, pipeline execution, and deployment state synchronization. 

This project demonstrates a zero-touch, pull-based GitOps deployment architecture utilizing ArgoCD, deployed on Amazon Elastic Kubernetes Service (EKS), and managed entirely through Infrastructure as Code (IaC).

## System Architecture

The infrastructure is provisioned dynamically via Terraform and relies on a strict GitOps philosophy where this GitHub repository acts as the absolute source of truth for the cluster state.

| Category | Technology | Purpose |
| :--- | :--- | :--- |
| **Cloud Provider** | Amazon Web Services (AWS) | Target infrastructure environment |
| **Infrastructure as Code** | Terraform | Automated provisioning of VPC, EKS, and RDS |
| **Backend API** | Spring Boot 3.x (Java 21) | Core auditing logic and metrics processing |
| **Database** | Amazon RDS (PostgreSQL) | Persistent storage for deployment metrics |
| **CI/CD Pipeline** | GitHub Actions | Automated testing, SAST/DAST, and container builds |
| **Container Registry** | Amazon ECR | Secure Docker image hosting |
| **GitOps Controller** | ArgoCD | Automated, pull-based cluster synchronization |
| **Observability** | Prometheus & Grafana | Time-series metrics and dashboarding |
| **Log Aggregation** | Fluent Bit & CloudWatch | Centralized pod log management via IRSA |

## Core Database Entities

The application tracks the complete software lifecycle, governed by state transitions of the Deployment object across the cluster.

| Entity | Attributes | Relationships |
| :--- | :--- | :--- |
| **Application** | `id` (UUID), `name`, `environment`, `currentImageTag` | One-to-Many with Deployment |
| **Deployment** | `id` (UUID), `timestamp`, `imageTag`, `status` | Many-to-One with Application |
| **Pipeline Run** | `id` (UUID), `commitSha`, `branch`, `triggeredBy`, `outcome` | One-to-One with Deployment |
| **Monitoring Metric** | `id` (UUID), `metricName`, `value`, `recordedAt` | Many-to-One with Deployment |

## Deployment Strategy (Zero-Touch GitOps)

This project abandons traditional push-based deployments in favor of a highly secure, pull-based reconciliation loop:

1. **Continuous Integration (CI):** Developers push code to the `main` branch. GitHub Actions triggers a workflow that runs unit tests, executes a Trivy vulnerability scan, builds the Docker image, and pushes it to Amazon ECR.
2. **Manifest Mutation:** The CI pipeline automatically updates the `deployment.yaml` manifest with the new cryptographic image hash and commits the change back to the repository.
3. **Continuous Delivery (CD):** ArgoCD, running inside the EKS cluster, detects configuration drift between the live cluster and the Git repository.
4. **Reconciliation:** ArgoCD automatically pulls the new deployment state, triggering Kubernetes to execute a rolling update of the ReplicaSet, ensuring zero downtime.

## Security & Reliability Implementations

* **Principle of Least Privilege (PoLP):** Amazon RDS database traffic is explicitly restricted at the network layer, accepting TCP port 5432 connections *only* from the cryptographic identity of the EKS Node Security Group.
* **Vulnerability Scanning:** Automated CI pipeline gates reject container images containing critical OS or library CVEs.
* **OOM Prevention:** Java Virtual Machine (JVM) memory constraints are hardcoded (`-Xmx256m -Xms128m`) and paired with Kubernetes resource limits to prevent pod starvation.
* **Concurrency Protection:** The initial cluster deployment scales to a single replica to ensure safe execution of Hibernate auto-DDL schema generation, preventing database lock race conditions.

## Local Development & Provisioning

### Prerequisites
* AWS CLI installed and authenticated
* Terraform >= 1.5
* Docker & kubectl

### Infrastructure Provisioning
```bash
cd terraform
terraform init
terraform apply
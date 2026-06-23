package dev.appmigration;

import dev.appmigration.domain.Deployment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface DeploymentRepository extends JpaRepository<Deployment, UUID> {
    // Optimized by the composite index for the GitOps controller
    List<Deployment> findByApplicationIdOrderByTimestampDesc(UUID applicationId);
}

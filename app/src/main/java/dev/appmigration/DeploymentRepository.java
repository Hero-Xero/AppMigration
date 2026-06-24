package dev.appmigration;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import dev.appmigration.domain.Deployment;

@Repository
public interface DeploymentRepository extends JpaRepository<Deployment, UUID> {

    List<Deployment> findByApplicationIdOrderByTimestampDesc(UUID applicationId);
}

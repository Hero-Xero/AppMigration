package dev.appmigration;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import dev.appmigration.domain.MonitoringMetric;

@Repository
public interface MonitoringMetricRepository extends JpaRepository<MonitoringMetric, UUID> {

    List<MonitoringMetric> findByDeploymentIdOrderByRecordedAtDesc(UUID deploymentId);
}
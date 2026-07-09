package dev.appmigration;

import dev.appmigration.domain.MonitoringMetric;
import dev.appmigration.domain.PipelineRun;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/deployments")
@RequiredArgsConstructor
public class DeploymentController {

    private final DeploymentRepository deploymentRepository;
    private final PipelineRunRepository pipelineRunRepository;
    private final MonitoringMetricRepository monitoringMetricRepository;

    @PostMapping("/{id}/pipeline-runs")
    public ResponseEntity<PipelineRun> addPipelineRun(@PathVariable UUID id, @RequestBody PipelineRun pipelineRun) {
        return deploymentRepository.findById(id)
                .map(deployment -> {
                    pipelineRun.setDeployment(deployment);
                    return ResponseEntity.ok(pipelineRunRepository.save(pipelineRun));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping("/{id}/metrics")
    public ResponseEntity<MonitoringMetric> addMetric(@PathVariable UUID id, @RequestBody MonitoringMetric metric) {
        return deploymentRepository.findById(id)
                .map(deployment -> {
                    metric.setDeployment(deployment);
                    return ResponseEntity.ok(monitoringMetricRepository.save(metric));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/{id}/pipeline-runs")
    public ResponseEntity<PipelineRun> getPipelineRun(@PathVariable UUID id) {
        return pipelineRunRepository.findByDeploymentId(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/{id}/metrics")
    public ResponseEntity<List<MonitoringMetric>> getMetrics(@PathVariable UUID id) {
        if (!deploymentRepository.existsById(id)) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(monitoringMetricRepository.findByDeploymentIdOrderByRecordedAtDesc(id));
    }
}
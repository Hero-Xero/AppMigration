package dev.appmigration;

import java.util.List;
import java.util.UUID;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import dev.appmigration.domain.Application;
import dev.appmigration.domain.Deployment;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/applications")
@RequiredArgsConstructor
public class ApplicationController {

    private final ApplicationRepository applicationRepository;
    private final DeploymentRepository deploymentRepository;

    @GetMapping
    public List<Application> getAllApplications() {
        return applicationRepository.findAll();
    }

    @PostMapping
    public Application createApplication(@RequestBody Application application) {
        return applicationRepository.save(application);
    }

    @GetMapping("/{id}")
    public ResponseEntity<Application> getApplicationById(@PathVariable UUID id) {
        return applicationRepository.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping("/{id}/deployments")
    public ResponseEntity<Deployment> createDeployment(@PathVariable UUID id, @RequestBody Deployment deployment) {
        return applicationRepository.findById(id)
                .map(application -> {
                    application.addDeployment(deployment);
                    applicationRepository.save(application);
                    return ResponseEntity.ok(deployment);
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/{id}/deployments")
    public ResponseEntity<List<Deployment>> getDeploymentsByApplication(@PathVariable UUID id) {
        if (!applicationRepository.existsById(id)) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(deploymentRepository.findByApplicationIdOrderByTimestampDesc(id));
    }
}

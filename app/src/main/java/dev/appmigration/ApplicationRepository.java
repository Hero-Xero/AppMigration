<<<<<<< HEAD
package dev.appmigration;

import dev.appmigration.domain.Application;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface ApplicationRepository extends JpaRepository<Application, UUID> {}

=======
package dev.appmigration;

import dev.appmigration.domain.Application;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface ApplicationRepository extends JpaRepository<Application, UUID> {}

>>>>>>> 5023c00f84a19861e7792608da5b28dd33b900f8

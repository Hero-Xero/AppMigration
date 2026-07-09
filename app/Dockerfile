# === Stage 1: Build Stage ===
FROM maven:3.9.6-eclipse-temurin-21 AS builder
WORKDIR /build

# Copy only the pom.xml first to cache dependencies (improves build speed)
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy the actual source code
COPY src ./src

# Package the application into a JAR file, skipping unit tests for speed
RUN mvn clean package -DskipTests

# === Stage 2: Runtime Stage ===
FROM eclipse-temurin:25-jre-alpine
WORKDIR /app

# Patch vulnerable Alpine packages
RUN apk upgrade --no-cache

# Create a non-root system user for security best practices
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring

# Copy the compiled JAR from the builder stage
COPY --from=builder /build/target/*.jar app.jar

# Expose the standard Spring Boot port
EXPOSE 8080

# Run the application
ENTRYPOINT ["java", "-Xms128m", "-Xmx256m", "-jar", "app.jar"]
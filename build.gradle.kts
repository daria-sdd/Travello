import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

plugins {
    id("org.springframework.boot")         version "3.3.0"
    id("io.spring.dependency-management")  version "1.1.5"
    id("org.flywaydb.flyway")              version "10.15.0"
    kotlin("jvm")                          version "2.0.0"
    kotlin("plugin.spring")                version "2.0.0"
    kotlin("plugin.serialization")         version "2.0.0"
}

group   = "com.wayai"
version = "0.0.1-SNAPSHOT"

java { sourceCompatibility = JavaVersion.VERSION_21 }

repositories {
    mavenCentral()
}

dependencies {
    // ---- Spring Boot ----
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-webflux")   // SSE / reactive
    implementation("org.springframework.boot:spring-boot-starter-security")
    implementation("org.springframework.boot:spring-boot-starter-validation")
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    implementation("org.springframework.boot:spring-boot-starter-data-redis")

    // ---- Kotlin ----
    implementation("org.jetbrains.kotlin:kotlin-reflect")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.8.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-reactor:1.8.1")  // coroutines + WebFlux
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.0")

    // ---- Database: Exposed ORM + PostgreSQL ----
    implementation("org.jetbrains.exposed:exposed-core:0.51.1")
    implementation("org.jetbrains.exposed:exposed-dao:0.51.1")
    implementation("org.jetbrains.exposed:exposed-jdbc:0.51.1")
    implementation("org.jetbrains.exposed:exposed-java-time:0.51.1")
    implementation("org.jetbrains.exposed:exposed-json:0.51.1")
    implementation("org.postgresql:postgresql:42.7.3")
    implementation("com.zaxxer:HikariCP:5.1.0")

    // ---- Migrations ----
    implementation("org.flywaydb:flyway-core:10.15.0")
    implementation("org.flywaydb:flyway-database-postgresql:10.15.0")

    // ---- Messaging: Kafka ----
    implementation("org.springframework.kafka:spring-kafka")

    // ---- AI: LangChain4j + Anthropic Claude ----
    implementation("dev.langchain4j:langchain4j:0.32.0")
    implementation("dev.langchain4j:langchain4j-anthropic:0.32.0")
    implementation("dev.langchain4j:langchain4j-core:0.32.0")

    // ---- HTTP client (for external APIs: Amadeus, OpenWeather, Google) ----
    implementation("io.ktor:ktor-client-core:2.3.12")
    implementation("io.ktor:ktor-client-cio:2.3.12")
    implementation("io.ktor:ktor-client-content-negotiation:2.3.12")
    implementation("io.ktor:ktor-serialization-jackson:2.3.12")
    implementation("io.ktor:ktor-client-logging:2.3.12")

    // ---- JSON ----
    implementation("com.fasterxml.jackson.module:jackson-module-kotlin")
    implementation("com.fasterxml.jackson.datatype:jackson-datatype-jsr310")

    // ---- Firebase Auth (server-side token verification) ----
    implementation("com.google.firebase:firebase-admin:9.3.0")

    // ---- AWS S3 (PDF / QR storage) ----
    implementation("software.amazon.awssdk:s3:2.26.12")

    // ---- Monitoring ----
    implementation("io.micrometer:micrometer-registry-prometheus")

    // ---- Test ----
    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("org.springframework.kafka:spring-kafka-test")
    testImplementation("io.mockk:mockk:1.13.11")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.8.1")
    testImplementation("org.testcontainers:postgresql:1.19.8")
    testImplementation("org.testcontainers:kafka:1.19.8")
}

tasks.withType<KotlinCompile> {
    kotlinOptions {
        freeCompilerArgs += "-Xjsr305=strict"
        jvmTarget = "21"
    }
}

tasks.withType<Test> { useJUnitPlatform() }

package com.wayai.config

import dev.langchain4j.model.anthropic.AnthropicChatModel
import io.ktor.client.*
import io.ktor.client.engine.cio.*
import io.ktor.client.plugins.*
import io.ktor.client.plugins.contentnegotiation.*
import io.ktor.client.plugins.logging.*
import io.ktor.serialization.jackson.*
import com.fasterxml.jackson.databind.DeserializationFeature
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.databind.SerializationFeature
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule
import com.fasterxml.jackson.module.kotlin.kotlinModule
import com.google.auth.oauth2.GoogleCredentials
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import software.amazon.awssdk.auth.credentials.DefaultAwsCredentialsProviderChain
import software.amazon.awssdk.regions.Region
import software.amazon.awssdk.services.s3.S3Client
import java.io.FileInputStream
import java.time.Duration

@Configuration
class AppConfig {

    // --------------------------------------------------------
    // Jackson ObjectMapper
    // --------------------------------------------------------

    @Bean
    fun objectMapper(): ObjectMapper = ObjectMapper().apply {
        registerModule(kotlinModule())
        registerModule(JavaTimeModule())
        disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS)
        disable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)
        setSerializationInclusion(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL)
    }

    // --------------------------------------------------------
    // Anthropic Claude model
    // --------------------------------------------------------

    @Bean
    fun anthropicChatModel(
        @Value("\${wayai.anthropic.api-key}")   apiKey: String,
        @Value("\${wayai.anthropic.model}")     model: String,
        @Value("\${wayai.anthropic.max-tokens}") maxTokens: Int,
    ): AnthropicChatModel = AnthropicChatModel.builder()
        .apiKey(apiKey)
        .modelName(model)
        .maxTokens(maxTokens)
        // Temperature 0.7: creative enough for engaging descriptions,
        // grounded enough for factual planning
        .temperature(0.7)
        // Extended timeout — complex tool-use chains take 30-60s
        .timeout(Duration.ofSeconds(120))
        .build()

    // --------------------------------------------------------
    // Ktor HTTP client (used by all external API clients)
    // --------------------------------------------------------

    @Bean
    fun httpClient(objectMapper: ObjectMapper): HttpClient = HttpClient(CIO) {
        install(ContentNegotiation) {
            jackson { objectMapper }
        }
        install(Logging) {
            level = LogLevel.INFO   // set DEBUG to see full request/response
        }
        install(HttpTimeout) {
            requestTimeoutMillis  = 15_000
            connectTimeoutMillis  = 5_000
            socketTimeoutMillis   = 15_000
        }
        install(HttpRequestRetry) {
            retryOnServerErrors(maxRetries = 2)
            exponentialDelay()
        }
        engine {
            maxConnectionsCount    = 64
            endpoint.maxConnectionsPerRoute = 16
        }
    }

    // --------------------------------------------------------
    // Firebase Admin SDK (server-side token verification)
    // --------------------------------------------------------

    @Bean
    fun firebaseApp(
        @Value("\${wayai.firebase.credentials-path}") credPath: String,
    ): FirebaseApp {
        if (FirebaseApp.getApps().isNotEmpty()) {
            return FirebaseApp.getInstance()
        }
        val options = FirebaseOptions.builder()
            .setCredentials(GoogleCredentials.fromStream(FileInputStream(credPath)))
            .build()
        return FirebaseApp.initializeApp(options)
    }

    // --------------------------------------------------------
    // AWS S3 (for PDF and QR code storage)
    // --------------------------------------------------------

    @Bean
    fun s3Client(
        @Value("\${wayai.aws.region}") region: String,
    ): S3Client = S3Client.builder()
        .region(Region.of(region))
        .credentialsProvider(DefaultAwsCredentialsProviderChain.create())
        .build()
}

package com.wayai.api

import com.fasterxml.jackson.databind.ObjectMapper
import com.wayai.domain.User
import com.wayai.infrastructure.db.UserRepository
import com.wayai.api.dto.UserDTO
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import jakarta.validation.constraints.NotBlank
import kotlinx.coroutines.runBlocking
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.web.bind.annotation.*
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.time.Instant
import java.util.Base64
import java.util.UUID

// ============================================================
// AUTH CONTROLLER
// POST /api/v1/auth/exchange  — Apple identity token → Firebase ID token + user
// GET  /api/v1/auth/me        — текущий пользователь
// ============================================================

@RestController
@RequestMapping("/api/v1/auth")
class AuthController(
    private val userRepository: UserRepository,
    private val firebaseApp: FirebaseApp,
    private val objectMapper: ObjectMapper,
    @Value("\${wayai.firebase.web-api-key}") private val firebaseWebApiKey: String,
) {
    private val log = LoggerFactory.getLogger(AuthController::class.java)
    private val http = HttpClient.newHttpClient()

    // ── Exchange Apple token → Firebase ID token ─────────────

    data class ExchangeRequest(
        @field:NotBlank val appleIdentityToken: String,
        val nonce: String = "",
        val displayName: String? = null,
    )

    data class ExchangeResponse(val token: String, val user: UserDTO)

    @PostMapping("/exchange")
    fun exchange(@RequestBody request: ExchangeRequest): ResponseEntity<ExchangeResponse> = runBlocking {
        // 1. Декодируем Apple JWT (payload — вторая часть base64) без верификации подписи.
        //    Для продакшна нужна полная верификация через Apple JWKS.
        val appleUid = decodeAppleSubject(request.appleIdentityToken)
            ?: return@runBlocking ResponseEntity.badRequest().build()

        val appleEmail = decodeAppleEmail(request.appleIdentityToken)

        log.info("auth.exchange: appleUid=$appleUid")

        // 2. Firebase custom token для этого Apple UID
        val customToken = FirebaseAuth.getInstance(firebaseApp).createCustomToken(appleUid)

        // 3. Обмен custom token → Firebase ID token через REST API
        val idToken = exchangeCustomToken(customToken)
            ?: return@runBlocking ResponseEntity.internalServerError().build()

        // 4. Найти или создать пользователя в БД
        val user = userRepository.findByFirebaseUid(appleUid) ?: run {
            val newUser = User(
                firebaseUid = appleUid,
                email       = appleEmail,
                displayName = request.displayName,
                createdAt   = Instant.now(),
                updatedAt   = Instant.now(),
            )
            userRepository.save(newUser)
        }

        log.info("auth.exchange: success userId=${user.id}")
        ResponseEntity.ok(ExchangeResponse(token = idToken, user = UserDTO.from(user)))
    }

    // ── Current user ─────────────────────────────────────────

    @GetMapping("/me")
    fun me(@AuthenticationPrincipal userId: UUID): ResponseEntity<UserDTO> = runBlocking {
        val user = userRepository.findById(userId)
            ?: return@runBlocking ResponseEntity.notFound().build()
        ResponseEntity.ok(UserDTO.from(user))
    }

    // ── Helpers ───────────────────────────────────────────────

    private fun decodeAppleSubject(jwt: String): String? = runCatching {
        val payload = jwt.split(".").getOrNull(1) ?: return null
        val decoded = Base64.getUrlDecoder().decode(padBase64(payload))
        val node    = objectMapper.readTree(decoded)
        node["sub"]?.asText()?.takeIf { it.isNotBlank() }
    }.getOrNull()

    private fun decodeAppleEmail(jwt: String): String? = runCatching {
        val payload = jwt.split(".").getOrNull(1) ?: return null
        val decoded = Base64.getUrlDecoder().decode(padBase64(payload))
        val node    = objectMapper.readTree(decoded)
        node["email"]?.asText()?.takeIf { it.isNotBlank() }
    }.getOrNull()

    private fun padBase64(s: String): String {
        val pad = (4 - s.length % 4) % 4
        return s + "=".repeat(pad)
    }

    private fun exchangeCustomToken(customToken: String): String? = runCatching {
        val body = objectMapper.writeValueAsString(
            mapOf("token" to customToken, "returnSecureToken" to true)
        )
        val request = HttpRequest.newBuilder()
            .uri(URI.create("https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=$firebaseWebApiKey"))
            .header("Content-Type", "application/json")
            .POST(HttpRequest.BodyPublishers.ofString(body))
            .build()

        val response = http.send(request, HttpResponse.BodyHandlers.ofString())
        if (response.statusCode() != 200) {
            log.error("Firebase token exchange failed: ${response.statusCode()} ${response.body()}")
            return null
        }
        objectMapper.readTree(response.body())["idToken"]?.asText()
    }.getOrElse { e ->
        log.error("Firebase token exchange error", e)
        null
    }
}

// ── User DTO ─────────────────────────────────────────────────

data class UserDTO(
    val id: UUID,
    val email: String?,
    val displayName: String?,
    val avatarUrl: String?,
    val locale: String,
    val currency: String,
) {
    companion object {
        fun from(u: User) = UserDTO(
            id          = u.id,
            email       = u.email,
            displayName = u.displayName,
            avatarUrl   = u.avatarUrl,
            locale      = u.locale,
            currency    = u.currency,
        )
    }
}

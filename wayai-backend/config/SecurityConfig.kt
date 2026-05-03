package com.wayai.config

import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.FirebaseAuthException
import jakarta.servlet.FilterChain
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken
import org.springframework.security.config.annotation.web.builders.HttpSecurity
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity
import org.springframework.security.config.http.SessionCreationPolicy
import org.springframework.security.core.authority.SimpleGrantedAuthority
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.security.web.SecurityFilterChain
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter
import org.springframework.stereotype.Component
import org.springframework.web.filter.OncePerRequestFilter
import java.util.UUID

@EnableWebSecurity
@Configuration
class SecurityConfig(private val firebaseFilter: FirebaseAuthFilter) {

    @Bean
    fun filterChain(http: HttpSecurity): SecurityFilterChain {
        http
            .csrf { it.disable() }
            .sessionManagement { it.sessionCreationPolicy(SessionCreationPolicy.STATELESS) }
            .authorizeHttpRequests { auth ->
                auth
                    // Публичные эндпоинты
                    .requestMatchers("/actuator/health", "/actuator/info").permitAll()
                    // Всё остальное — только с валидным Firebase токеном
                    .anyRequest().authenticated()
            }
            .addFilterBefore(firebaseFilter, UsernamePasswordAuthenticationFilter::class.java)

        return http.build()
    }
}

// ============================================================
// FIREBASE JWT FILTER
// Извлекает Firebase ID token из Authorization: Bearer <token>,
// верифицирует через Firebase Admin SDK,
// кладёт userId в SecurityContext.
// ============================================================

@Component
class FirebaseAuthFilter(private val firebaseApp: FirebaseApp) : OncePerRequestFilter() {

    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        chain: FilterChain,
    ) {
        val token = extractToken(request)

        if (token != null) {
            runCatching {
                val decoded = FirebaseAuth.getInstance(firebaseApp).verifyIdToken(token)
                // uid хранится в Firebase — это строка, не UUID.
                // Наш внутренний UUID мы резолвим в UserRepository по firebaseUid.
                // Для @AuthenticationPrincipal в контроллерах кладём firebaseUid как строку.
                val auth = UsernamePasswordAuthenticationToken(
                    decoded.uid,                                       // principal = firebaseUid
                    null,
                    listOf(SimpleGrantedAuthority("ROLE_USER")),
                )
                SecurityContextHolder.getContext().authentication = auth
            }.onFailure { e ->
                when (e) {
                    is FirebaseAuthException -> {
                        response.status = HttpServletResponse.SC_UNAUTHORIZED
                        response.writer.write("""{"error":"Invalid token","code":"${e.authErrorCode}"}""")
                        return
                    }
                    else -> logger.warn("Firebase auth error: ${e.message}")
                }
            }
        }

        chain.doFilter(request, response)
    }

    private fun extractToken(request: HttpServletRequest): String? {
        val header = request.getHeader("Authorization") ?: return null
        if (!header.startsWith("Bearer ")) return null
        return header.substring(7).trim().takeIf { it.isNotBlank() }
    }

    // SSE endpoint не требует тела — пропускаем только проверку тела,
    // но токен всё равно нужен
    override fun shouldNotFilterAsyncDispatch() = false
}

package com.wayai.config

import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.FirebaseAuthException
import com.wayai.infrastructure.db.UserRepository
import jakarta.servlet.FilterChain
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import kotlinx.coroutines.runBlocking
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
                    .requestMatchers(
                        "/actuator/health",
                        "/actuator/info",
                        "/api/v1/auth/exchange",   // публичный — iOS вызывает без токена
                    ).permitAll()
                    .anyRequest().authenticated()
            }
            .addFilterBefore(firebaseFilter, UsernamePasswordAuthenticationFilter::class.java)

        return http.build()
    }
}

// ============================================================
// FIREBASE JWT FILTER
// 1. Берёт Firebase ID token из Authorization: Bearer <token>
// 2. Верифицирует через Firebase Admin SDK
// 3. Резолвит firebaseUid → внутренний UUID пользователя из БД
// 4. Кладёт UUID в SecurityContext (principal)
// ============================================================

@Component
class FirebaseAuthFilter(
    private val firebaseApp: FirebaseApp,
    private val userRepository: UserRepository,
) : OncePerRequestFilter() {

    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        chain: FilterChain,
    ) {
        val token = extractToken(request)

        if (token != null) {
            try {
                val decoded = FirebaseAuth.getInstance(firebaseApp).verifyIdToken(token)

                // Резолвим firebaseUid → внутренний UUID из БД
                val user = runBlocking { userRepository.findByFirebaseUid(decoded.uid) }

                if (user == null) {
                    // Пользователь ещё не зарегистрирован — пусть зовёт /auth/exchange
                    response.status = HttpServletResponse.SC_UNAUTHORIZED
                    response.writer.write("""{"error":"User not registered","code":"USER_NOT_FOUND"}""")
                    return
                }

                val auth = UsernamePasswordAuthenticationToken(
                    user.id,                                           // principal = UUID
                    null,
                    listOf(SimpleGrantedAuthority("ROLE_USER")),
                )
                SecurityContextHolder.getContext().authentication = auth

            } catch (e: FirebaseAuthException) {
                response.status = HttpServletResponse.SC_UNAUTHORIZED
                response.writer.write("""{"error":"Invalid token","code":"${e.authErrorCode}"}""")
                return
            } catch (e: Exception) {
                logger.warn("Firebase auth error: ${e.message}")
            }
        }

        chain.doFilter(request, response)
    }

    private fun extractToken(request: HttpServletRequest): String? {
        val header = request.getHeader("Authorization") ?: return null
        if (!header.startsWith("Bearer ")) return null
        return header.substring(7).trim().takeIf { it.isNotBlank() }
    }

    override fun shouldNotFilterAsyncDispatch() = false
}

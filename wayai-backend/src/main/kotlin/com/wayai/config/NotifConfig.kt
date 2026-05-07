package com.wayai.config

import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.data.redis.connection.RedisConnectionFactory
import org.springframework.data.redis.listener.RedisMessageListenerContainer
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor

// ============================================================
// NOTIF CONFIG
// Redis listener container — нужен для SseRedisRelay.
// Подписывается на sse:survey:* и форвардит события в SSE.
// ============================================================

@Configuration
class NotifConfig {

    @Bean
    fun redisMessageListenerContainer(
        factory: RedisConnectionFactory,
    ): RedisMessageListenerContainer {
        val executor = ThreadPoolTaskExecutor().apply {
            corePoolSize     = 2
            maxPoolSize      = 4
            threadNamePrefix = "redis-pubsub-"
            initialize()
        }
        return RedisMessageListenerContainer().apply {
            setConnectionFactory(factory)
            setTaskExecutor(executor)
        }
    }
}

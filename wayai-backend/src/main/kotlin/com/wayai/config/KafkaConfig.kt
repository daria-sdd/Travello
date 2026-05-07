package com.wayai.config

import com.wayai.infrastructure.kafka.RouteGenerationEvent
import org.apache.kafka.clients.consumer.ConsumerConfig
import org.apache.kafka.clients.producer.ProducerConfig
import org.apache.kafka.common.serialization.StringDeserializer
import org.apache.kafka.common.serialization.StringSerializer
import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.kafka.annotation.EnableKafka
import org.springframework.kafka.config.ConcurrentKafkaListenerContainerFactory
import org.springframework.kafka.core.*
import org.springframework.kafka.listener.ContainerProperties
import org.springframework.kafka.support.serializer.JsonDeserializer
import org.springframework.kafka.support.serializer.JsonSerializer

@EnableKafka
@Configuration
class KafkaConfig(
    @Value("\${spring.kafka.bootstrap-servers}") private val bootstrapServers: String,
) {

    // ---- Producer ----

    @Bean
    fun producerFactory(): ProducerFactory<String, RouteGenerationEvent> {
        val props = mapOf(
            ProducerConfig.BOOTSTRAP_SERVERS_CONFIG        to bootstrapServers,
            ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG     to StringSerializer::class.java,
            ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG   to JsonSerializer::class.java,
            // Ждём подтверждения от всех реплик (надёжность)
            ProducerConfig.ACKS_CONFIG                     to "all",
            // Идемпотентный producer — нет дублей при retry
            ProducerConfig.ENABLE_IDEMPOTENCE_CONFIG       to true,
        )
        return DefaultKafkaProducerFactory(props)
    }

    @Bean
    fun kafkaTemplate(): KafkaTemplate<String, RouteGenerationEvent> =
        KafkaTemplate(producerFactory())

    // ---- Consumer (ручное подтверждение offset) ----

    @Bean
    fun consumerFactory(): ConsumerFactory<String, RouteGenerationEvent> {
        val props = mapOf(
            ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG  to bootstrapServers,
            ConsumerConfig.GROUP_ID_CONFIG           to "wayai-route-generator",
            ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG   to StringDeserializer::class.java,
            ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG to JsonDeserializer::class.java,
            ConsumerConfig.AUTO_OFFSET_RESET_CONFIG  to "earliest",
            // Не коммитим offset автоматически — только после успешной обработки
            ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG to false,
            JsonDeserializer.TRUSTED_PACKAGES        to "com.wayai.*",
            JsonDeserializer.VALUE_DEFAULT_TYPE      to RouteGenerationEvent::class.java.name,
        )
        return DefaultKafkaConsumerFactory(props)
    }

    @Bean
    fun manualAckKafkaListenerContainerFactory(): ConcurrentKafkaListenerContainerFactory<String, RouteGenerationEvent> {
        val factory = ConcurrentKafkaListenerContainerFactory<String, RouteGenerationEvent>()
        factory.consumerFactory = consumerFactory()
        // Ручное подтверждение: ack.acknowledge() вызывается в коде после обработки
        factory.containerProperties.ackMode = ContainerProperties.AckMode.MANUAL_IMMEDIATE
        // Параллельность: 3 потока = 3 survey одновременно (по числу партиций)
        factory.setConcurrency(3)
        return factory
    }
}

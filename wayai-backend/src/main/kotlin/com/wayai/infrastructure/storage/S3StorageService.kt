package com.wayai.infrastructure.storage

import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import software.amazon.awssdk.core.sync.RequestBody
import software.amazon.awssdk.services.s3.S3Client
import software.amazon.awssdk.services.s3.model.GetUrlRequest
import software.amazon.awssdk.services.s3.model.PutObjectRequest
import java.util.UUID

// ============================================================
// S3 STORAGE SERVICE
// Загрузка PDF маршрутов и QR-кодов бронирований в S3 / R2.
// ============================================================

@Service
class S3StorageService(
    private val s3: S3Client,
    @Value("\${wayai.aws.bucket-name}") private val bucket: String,
) {
    private val log = LoggerFactory.getLogger(S3StorageService::class.java)

    // Загрузить PDF маршрута
    fun uploadRoutePdf(routeId: UUID, pdfBytes: ByteArray): String {
        val key = "routes/$routeId/plan.pdf"
        upload(key, pdfBytes, "application/pdf")
        return publicUrl(key)
    }

    // Загрузить QR-код бронирования
    fun uploadBookingQr(bookingId: UUID, pngBytes: ByteArray): String {
        val key = "bookings/$bookingId/qr.png"
        upload(key, pngBytes, "image/png")
        return publicUrl(key)
    }

    // Загрузить произвольный файл
    fun upload(key: String, bytes: ByteArray, contentType: String): String {
        val request = PutObjectRequest.builder()
            .bucket(bucket)
            .key(key)
            .contentType(contentType)
            .contentLength(bytes.size.toLong())
            // Публичное чтение — для прямой отдачи в приложение
            .build()

        runCatching {
            s3.putObject(request, RequestBody.fromBytes(bytes))
            log.info("Uploaded s3://$bucket/$key (${bytes.size} bytes)")
        }.onFailure { e ->
            log.error("S3 upload failed for key=$key: ${e.message}")
            throw e
        }
        return publicUrl(key)
    }

    fun delete(key: String) {
        runCatching {
            s3.deleteObject { it.bucket(bucket).key(key) }
            log.info("Deleted s3://$bucket/$key")
        }.onFailure { e ->
            log.warn("S3 delete failed for key=$key: ${e.message}")
        }
    }

    private fun publicUrl(key: String): String =
        s3.utilities()
            .getUrl(GetUrlRequest.builder().bucket(bucket).key(key).build())
            .toString()
}

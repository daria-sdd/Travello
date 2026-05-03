package com.wayai.api

import com.wayai.domain.Booking
import com.wayai.domain.BookingStatus
import com.wayai.infrastructure.db.BookingRepository
import com.wayai.infrastructure.storage.S3StorageService
import jakarta.validation.constraints.NotBlank
import kotlinx.coroutines.runBlocking
import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.web.bind.annotation.*
import java.math.BigDecimal
import java.time.Instant
import java.util.UUID

// ============================================================
// BOOKING CONTROLLER
// GET    /api/v1/bookings             — все брони пользователя
// GET    /api/v1/bookings/{id}        — конкретная бронь
// POST   /api/v1/bookings             — добавить вручную
// PUT    /api/v1/bookings/{id}        — обновить (ref, статус)
// DELETE /api/v1/bookings/{id}        — удалить
// POST   /api/v1/bookings/{id}/qr     — загрузить QR в S3
// ============================================================

@RestController
@RequestMapping("/api/v1/bookings")
class BookingController(
    private val bookingRepository: BookingRepository,
    private val s3: S3StorageService,
) {

    @GetMapping
    fun list(@AuthenticationPrincipal firebaseUid: String): ResponseEntity<List<BookingDto>> =
        runBlocking {
            val userId = firebaseUid.toUUIDOrNull() ?: return@runBlocking ResponseEntity.badRequest().build()
            val bookings = bookingRepository.findByUserId(userId).map { BookingDto.from(it) }
            ResponseEntity.ok(bookings)
        }

    @GetMapping("/{id}")
    fun get(
        @PathVariable id: UUID,
        @AuthenticationPrincipal firebaseUid: String,
    ): ResponseEntity<BookingDto> = runBlocking {
        val booking = bookingRepository.findById(id)
            ?: return@runBlocking ResponseEntity.notFound().build()
        ResponseEntity.ok(BookingDto.from(booking))
    }

    @PostMapping
    fun create(
        @RequestBody request: CreateBookingRequest,
        @AuthenticationPrincipal firebaseUid: String,
    ): ResponseEntity<BookingDto> = runBlocking {
        val userId = firebaseUid.toUUIDOrNull() ?: return@runBlocking ResponseEntity.badRequest().build()
        val booking = bookingRepository.save(Booking(
            userId         = userId,
            routeEventId   = request.routeEventId,
            status         = BookingStatus.CONFIRMED,
            bookingRef     = request.bookingRef,
            providerName   = request.providerName,
            bookingUrl     = request.bookingUrl,
            bookedAt       = Instant.now(),
            validFrom      = request.validFrom?.let { Instant.parse(it) },
            validTo        = request.validTo?.let { Instant.parse(it) },
            amountPaid     = request.amountPaid?.let { BigDecimal(it) },
            currency       = request.currency ?: "USD",
        ))
        ResponseEntity.ok(BookingDto.from(booking))
    }

    @PutMapping("/{id}")
    fun update(
        @PathVariable id: UUID,
        @RequestBody request: UpdateBookingRequest,
        @AuthenticationPrincipal firebaseUid: String,
    ): ResponseEntity<BookingDto> = runBlocking {
        val booking = bookingRepository.findById(id)
            ?: return@runBlocking ResponseEntity.notFound().build()

        val updated = bookingRepository.update(booking.copy(
            bookingRef   = request.bookingRef   ?: booking.bookingRef,
            status       = request.status?.let { BookingStatus.valueOf(it.uppercase()) } ?: booking.status,
            bookingUrl   = request.bookingUrl   ?: booking.bookingUrl,
        ))
        ResponseEntity.ok(BookingDto.from(updated))
    }

    // Загрузка QR-кода — iOS присылает PNG байты в base64
    @PostMapping("/{id}/qr")
    fun uploadQr(
        @PathVariable id: UUID,
        @RequestBody request: QrUploadRequest,
        @AuthenticationPrincipal firebaseUid: String,
    ): ResponseEntity<Map<String, String>> = runBlocking {
        val booking = bookingRepository.findById(id)
            ?: return@runBlocking ResponseEntity.notFound().build()

        val bytes  = java.util.Base64.getDecoder().decode(request.pngBase64)
        val url    = s3.uploadBookingQr(id, bytes)
        bookingRepository.update(booking.copy(qrCodeUrl = url))

        ResponseEntity.ok(mapOf("qrCodeUrl" to url))
    }
}

// ---- DTOs ----

data class BookingDto(
    val id: UUID,
    val routeEventId: UUID?,
    val status: String,
    val bookingRef: String?,
    val providerName: String?,
    val providerLogo: String?,
    val bookingUrl: String?,
    val bookedAt: String?,
    val validFrom: String?,
    val validTo: String?,
    val amountPaid: Double?,
    val currency: String,
    val qrCodeUrl: String?,
    val ticketPdfUrl: String?,
) {
    companion object {
        fun from(b: Booking) = BookingDto(
            id            = b.id,
            routeEventId  = b.routeEventId,
            status        = b.status.name.lowercase(),
            bookingRef    = b.bookingRef,
            providerName  = b.providerName,
            providerLogo  = b.providerLogo,
            bookingUrl    = b.bookingUrl,
            bookedAt      = b.bookedAt?.toString(),
            validFrom     = b.validFrom?.toString(),
            validTo       = b.validTo?.toString(),
            amountPaid    = b.amountPaid?.toDouble(),
            currency      = b.currency,
            qrCodeUrl     = b.qrCodeUrl,
            ticketPdfUrl  = b.ticketPdfUrl,
        )
    }
}

data class CreateBookingRequest(
    val routeEventId: UUID?,
    @field:NotBlank val providerName: String?,
    val bookingRef: String?,
    val bookingUrl: String?,
    val validFrom: String?,
    val validTo: String?,
    val amountPaid: String?,
    val currency: String?,
)

data class UpdateBookingRequest(
    val bookingRef: String?,
    val status: String?,
    val bookingUrl: String?,
)

data class QrUploadRequest(val pngBase64: String)

private fun String.toUUIDOrNull(): UUID? = runCatching { UUID.fromString(this) }.getOrNull()

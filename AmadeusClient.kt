package com.wayai.infrastructure.ai.clients

import com.wayai.infrastructure.ai.*
import io.ktor.client.*
import io.ktor.client.call.*
import io.ktor.client.request.*
import io.ktor.client.request.forms.*
import io.ktor.http.*
import kotlinx.coroutines.runBlocking
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.concurrent.atomic.AtomicReference

// ============================================================
// AMADEUS CLIENT
// Wraps the Amadeus REST API for flight and hotel search.
// Uses OAuth2 client_credentials. Token is cached and refreshed.
//
// Docs: https://developers.amadeus.com/self-service
// ============================================================

@Component
class AmadeusClient(
    private val httpClient: HttpClient,
    @Value("\${wayai.amadeus.client-id}")    private val clientId: String,
    @Value("\${wayai.amadeus.client-secret}") private val clientSecret: String,
    @Value("\${wayai.amadeus.base-url}")      private val baseUrl: String,
) {
    private val log   = LoggerFactory.getLogger(AmadeusClient::class.java)
    private val token = AtomicReference<AmadeusToken?>(null)

    // ----------------------------------------------------------
    // FLIGHTS
    // ----------------------------------------------------------

    fun searchFlights(
        origin: String,
        destination: String,
        departDate: LocalDate,
        returnDate: LocalDate?,
        adults: Int,
        travelClass: String,
        maxResults: Int,
    ): FlightSearchResult = runBlocking {
        val accessToken = getToken()

        runCatching {
            val response: AmadeusFlightOffersResponse = httpClient.get(
                "$baseUrl/v2/shopping/flight-offers"
            ) {
                bearerAuth(accessToken)
                parameter("originLocationCode",       resolveAirport(origin))
                parameter("destinationLocationCode",   resolveAirport(destination))
                parameter("departureDate",             departDate.format(DATE_FMT))
                returnDate?.let { parameter("returnDate", it.format(DATE_FMT)) }
                parameter("adults",        adults)
                parameter("travelClass",   travelClass.uppercase())
                parameter("max",           maxResults)
                parameter("currencyCode",  "USD")
            }.body()

            val offers = response.data.map { offer ->
                val seg   = offer.itineraries.first().segments.first()
                val price = offer.price.total.toDoubleOrNull() ?: 0.0
                FlightOffer(
                    offerId          = offer.id,
                    airline          = seg.carrierCode,
                    flightNumber     = "${seg.carrierCode}${seg.number}",
                    departureTime    = seg.departure.at,
                    arrivalTime      = seg.arrival.at,
                    durationHours    = parseDuration(offer.itineraries.first().duration),
                    stops            = offer.itineraries.first().segments.size - 1,
                    pricePerPerson   = price / adults,
                    currency         = offer.price.currency,
                    cabinClass       = travelClass,
                    baggageIncluded  = offer.travelerPricings.firstOrNull()
                        ?.fareDetailsBySegment?.firstOrNull()
                        ?.includedCheckedBags?.quantity?.let { it > 0 } ?: false,
                    seatsAvailable   = offer.numberOfBookableSeats,
                )
            }

            FlightSearchResult(
                found         = offers.isNotEmpty(),
                offers        = offers,
                searchSummary = if (offers.isEmpty())
                    "No direct flights found for $origin → $destination on $departDate."
                else
                    "Found ${offers.size} flight options. Cheapest: \$${offers.minOf { it.pricePerPerson }}/person.",
            )
        }.getOrElse { e ->
            log.error("Amadeus flight search error", e)
            FlightSearchResult(
                found         = false,
                offers        = emptyList(),
                searchSummary = "Flight search failed: ${e.message}. Try alternative airports.",
            )
        }
    }

    fun findCheapestDates(origin: String, destination: String): CheapestDatesResult = runBlocking {
        val accessToken = getToken()

        runCatching {
            val response: AmadeusFlightDatesResponse = httpClient.get(
                "$baseUrl/v1/shopping/flight-dates"
            ) {
                bearerAuth(accessToken)
                parameter("origin",      resolveAirport(origin))
                parameter("destination", resolveAirport(destination))
            }.body()

            CheapestDatesResult(
                origin      = origin,
                destination = destination,
                cheapestOptions = response.data.take(10).map { item ->
                    CheapDateOption(
                        departureDate   = item.departureDate,
                        returnDate      = item.returnDate,
                        pricePerPerson  = item.price.total.toDoubleOrNull() ?: 0.0,
                        currency        = "USD",
                    )
                },
            )
        }.getOrElse { e ->
            log.error("Amadeus cheapest dates error", e)
            CheapestDatesResult(origin, destination, emptyList())
        }
    }

    fun findDestinationInspiration(
        origin: String,
        departureMonth: String,
        maxBudget: Int,
    ): DestinationInspirationResult = runBlocking {
        val accessToken = getToken()

        runCatching {
            val response: AmadeusFlightInspirationResponse = httpClient.get(
                "$baseUrl/v1/shopping/flight-destinations"
            ) {
                bearerAuth(accessToken)
                parameter("origin",   resolveAirport(origin))
                parameter("maxPrice", maxBudget)
                if (departureMonth.isNotBlank()) {
                    parameter("departureDate", "$departureMonth-01")
                }
            }.body()

            DestinationInspirationResult(
                origin = origin,
                destinations = response.data.take(10).map { item ->
                    InspirationDestination(
                        destination   = item.destination,
                        country       = item.destination, // enriched by Claude from its knowledge
                        priceFrom     = item.price.total.toDoubleOrNull() ?: 0.0,
                        currency      = "USD",
                        departureDate = item.departureDate,
                        highlights    = emptyList(),
                    )
                },
            )
        }.getOrElse { e ->
            log.error("Amadeus inspiration error", e)
            DestinationInspirationResult(origin, emptyList())
        }
    }

    // ----------------------------------------------------------
    // HOTELS
    // ----------------------------------------------------------

    fun searchHotels(
        city: String,
        checkIn: LocalDate,
        checkOut: LocalDate,
        adults: Int,
        budgetTier: String,
        maxResults: Int,
    ): HotelSearchResult = runBlocking {
        val accessToken = getToken()

        runCatching {
            // Step 1: Get hotel IDs for city
            val listResponse: AmadeusHotelListResponse = httpClient.get(
                "$baseUrl/v1/reference-data/locations/hotels/by-city"
            ) {
                bearerAuth(accessToken)
                parameter("cityCode", resolveCityCode(city))
                parameter("radius",   5)
                parameter("radiusUnit", "KM")
                parameter("ratings",  hotelRatingsForTier(budgetTier))
            }.body()

            val hotelIds = listResponse.data.take(20).map { it.hotelId }
            if (hotelIds.isEmpty()) {
                return@runBlocking HotelSearchResult(false, emptyList(), "No hotels found in $city.")
            }

            // Step 2: Get offers for those hotels
            val offersResponse: AmadeusHotelOffersResponse = httpClient.get(
                "$baseUrl/v3/shopping/hotel-offers"
            ) {
                bearerAuth(accessToken)
                parameter("hotelIds",    hotelIds.take(10).joinToString(","))
                parameter("adults",      adults)
                parameter("checkInDate", checkIn.format(DATE_FMT))
                parameter("checkOutDate", checkOut.format(DATE_FMT))
                parameter("currencyCode", "USD")
                parameter("bestRateOnly", true)
            }.body()

            val nights = checkIn.until(checkOut, java.time.temporal.ChronoUnit.DAYS).toInt()
            val hotels = offersResponse.data.take(maxResults).map { item ->
                val offer   = item.offers.first()
                val total   = offer.price.total.toDoubleOrNull() ?: 0.0
                HotelOffer(
                    hotelId              = item.hotel.hotelId,
                    name                 = item.hotel.name,
                    stars                = item.hotel.rating?.toIntOrNull() ?: 3,
                    rating               = null,
                    reviewCount          = null,
                    address              = item.hotel.address?.lines?.joinToString(", ") ?: city,
                    distanceToCenterKm   = null,
                    pricePerNight        = if (nights > 0) total / nights else total,
                    totalPrice           = total,
                    currency             = offer.price.currency,
                    breakfastIncluded    = offer.boardType?.contains("BREAKFAST") == true,
                    cancellationPolicy   = offer.policies?.cancellations?.firstOrNull()
                        ?.description?.text ?: "See hotel policy",
                    amenities            = item.hotel.amenities ?: emptyList(),
                    imageUrl             = null,
                )
            }

            HotelSearchResult(
                found         = hotels.isNotEmpty(),
                hotels        = hotels,
                searchSummary = if (hotels.isEmpty())
                    "No available hotels found in $city for those dates."
                else
                    "Found ${hotels.size} hotels. Cheapest: \$${hotels.minOf { it.pricePerNight }.toInt()}/night.",
            )
        }.getOrElse { e ->
            log.error("Amadeus hotel search error", e)
            HotelSearchResult(false, emptyList(), "Hotel search failed: ${e.message}")
        }
    }

    // ----------------------------------------------------------
    // AUTH: OAuth2 client_credentials with auto-refresh
    // ----------------------------------------------------------

    private suspend fun getToken(): String {
        val current = token.get()
        if (current != null && !current.isExpired()) return current.accessToken

        val response: AmadeusTokenResponse = httpClient.post("$baseUrl/v1/security/oauth2/token") {
            contentType(ContentType.Application.FormUrlEncoded)
            setBody(FormDataContent(Parameters.build {
                append("grant_type",    "client_credentials")
                append("client_id",     clientId)
                append("client_secret", clientSecret)
            }))
        }.body()

        val newToken = AmadeusToken(
            accessToken = response.access_token,
            expiresAt   = System.currentTimeMillis() + (response.expires_in - 30) * 1000L,
        )
        token.set(newToken)
        log.debug("Amadeus token refreshed, expires in ${response.expires_in}s")
        return newToken.accessToken
    }

    // ----------------------------------------------------------
    // HELPERS
    // ----------------------------------------------------------

    // Very basic resolver — in production use Amadeus Airport & City Search API
    private fun resolveAirport(input: String): String {
        val upper = input.trim().uppercase()
        return when {
            upper.length == 3 -> upper          // already IATA
            else -> CITY_TO_IATA[upper] ?: upper.take(3)
        }
    }

    private fun resolveCityCode(city: String): String =
        CITY_TO_IATA[city.trim().uppercase()]?.take(3)
            ?: city.trim().uppercase().take(3)

    private fun hotelRatingsForTier(tier: String): String = when (tier.uppercase()) {
        "BUDGET"  -> "1,2,3"
        "LUXURY"  -> "4,5"
        else      -> "3,4"
    }

    private fun parseDuration(iso: String): Double {
        // "PT2H35M" → 2.58
        val h = Regex("(\\d+)H").find(iso)?.groupValues?.get(1)?.toDouble() ?: 0.0
        val m = Regex("(\\d+)M").find(iso)?.groupValues?.get(1)?.toDouble() ?: 0.0
        return h + m / 60
    }

    companion object {
        private val DATE_FMT = DateTimeFormatter.ISO_LOCAL_DATE

        // Expand as needed. Real production: use Amadeus Airport & City Search API.
        private val CITY_TO_IATA = mapOf(
            "MOSCOW"    to "SVO",
            "ISTANBUL"  to "IST",
            "ANTALYA"   to "AYT",
            "FETHIYE"   to "DLM",  // Dalaman, nearest airport
            "AMSTERDAM" to "AMS",
            "LONDON"    to "LHR",
            "PARIS"     to "CDG",
            "DUBAI"     to "DXB",
            "BANGKOK"   to "BKK",
            "BALI"      to "DPS",
            "ROME"      to "FCO",
            "BARCELONA" to "BCN",
            "PRAGUE"    to "PRG",
            "LISBON"    to "LIS",
        )
    }
}

// ============================================================
// TOKEN CACHE
// ============================================================

data class AmadeusToken(
    val accessToken: String,
    val expiresAt: Long,
) {
    fun isExpired() = System.currentTimeMillis() >= expiresAt
}

// ============================================================
// AMADEUS API RESPONSE SHAPES (simplified)
// Full Amadeus response is enormous — map only what we need.
// ============================================================

data class AmadeusTokenResponse(
    val access_token: String,
    val expires_in: Int,
)

data class AmadeusFlightOffersResponse(val data: List<AmadeusFlightOffer> = emptyList())
data class AmadeusFlightOffer(
    val id: String,
    val numberOfBookableSeats: Int?,
    val itineraries: List<AmadeusItinerary>,
    val price: AmadeusPrice,
    val travelerPricings: List<AmadeusTravelerPricing> = emptyList(),
)
data class AmadeusItinerary(val duration: String, val segments: List<AmadeusSegment>)
data class AmadeusSegment(
    val departure: AmadeusEndpoint,
    val arrival: AmadeusEndpoint,
    val carrierCode: String,
    val number: String,
)
data class AmadeusEndpoint(val iataCode: String, val at: String)
data class AmadeusPrice(val total: String, val currency: String)
data class AmadeusTravelerPricing(val fareDetailsBySegment: List<AmadeusFareDetail> = emptyList())
data class AmadeusFareDetail(val includedCheckedBags: AmadeusBags?)
data class AmadeusBags(val quantity: Int)

data class AmadeusFlightDatesResponse(val data: List<AmadeusFlightDate> = emptyList())
data class AmadeusFlightDate(val departureDate: String, val returnDate: String?, val price: AmadeusPrice)

data class AmadeusFlightInspirationResponse(val data: List<AmadeusDestination> = emptyList())
data class AmadeusDestination(val destination: String, val departureDate: String?, val price: AmadeusPrice)

data class AmadeusHotelListResponse(val data: List<AmadeusHotelRef> = emptyList())
data class AmadeusHotelRef(val hotelId: String)

data class AmadeusHotelOffersResponse(val data: List<AmadeusHotelOfferItem> = emptyList())
data class AmadeusHotelOfferItem(val hotel: AmadeusHotelInfo, val offers: List<AmadeusHotelOffer>)
data class AmadeusHotelInfo(
    val hotelId: String,
    val name: String,
    val rating: String?,
    val address: AmadeusAddress?,
    val amenities: List<String>?,
)
data class AmadeusAddress(val lines: List<String>?)
data class AmadeusHotelOffer(
    val price: AmadeusPrice,
    val boardType: String?,
    val policies: AmadeusPolicies?,
)
data class AmadeusPolicies(val cancellations: List<AmadeusCancellation>?)
data class AmadeusCancellation(val description: AmadeusDescription?)
data class AmadeusDescription(val text: String)

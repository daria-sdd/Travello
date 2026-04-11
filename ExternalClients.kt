package com.wayai.infrastructure.ai.clients

import com.wayai.infrastructure.ai.*
import io.ktor.client.*
import io.ktor.client.call.*
import io.ktor.client.request.*
import kotlinx.coroutines.runBlocking
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component
import java.time.LocalDate
import java.time.format.DateTimeFormatter

// ============================================================
// OPENWEATHER CLIENT
// ============================================================

@Component
class OpenWeatherClient(
    private val httpClient: HttpClient,
    @Value("\${wayai.openweather.api-key}") private val apiKey: String,
) {
    private val log = LoggerFactory.getLogger(OpenWeatherClient::class.java)

    fun getForecast(city: String, dateFrom: LocalDate, dateTo: LocalDate): WeatherForecastResult =
        runBlocking {
            runCatching {
                // OpenWeather 5-day forecast (free tier, 3h intervals)
                val response: OpenWeatherForecastResponse = httpClient.get(
                    "https://api.openweathermap.org/data/2.5/forecast"
                ) {
                    parameter("q",     city)
                    parameter("appid", apiKey)
                    parameter("units", "metric")
                    parameter("cnt",   40) // max 5 days
                }.body()

                // Group 3-hour slots by day, pick daily min/max
                val grouped = response.list
                    .groupBy { it.dt_txt.substring(0, 10) }
                    .filterKeys { date ->
                        val d = LocalDate.parse(date)
                        !d.isBefore(dateFrom) && !d.isAfter(dateTo)
                    }

                val days = grouped.entries.sortedBy { it.key }.map { (date, slots) ->
                    val temps    = slots.map { it.main.temp }
                    val rainProb = (slots.maxOfOrNull { it.pop } ?: 0.0) * 100
                    val cond     = slots[slots.size / 2].weather.firstOrNull()?.main ?: "Clear"
                    WeatherDay(
                        date            = date,
                        tempMinC        = temps.min(),
                        tempMaxC        = temps.max(),
                        condition       = cond,
                        rainProbability = rainProb.toInt(),
                        humidity        = slots.first().main.humidity,
                        windKmh         = slots.first().wind.speed * 3.6,
                    )
                }

                val summary = if (days.isEmpty()) {
                    "No forecast available for $city"
                } else {
                    val avgMax = days.map { it.tempMaxC }.average()
                    val rainy  = days.count { it.rainProbability > 40 }
                    "Avg high %.0f°C. %s".format(
                        avgMax,
                        if (rainy == 0) "No rain expected." else "$rainy day(s) with possible rain."
                    )
                }

                WeatherForecastResult(city = city, days = days, summary = summary)
            }.getOrElse { e ->
                log.error("OpenWeather forecast error for $city", e)
                WeatherForecastResult(
                    city = city,
                    days = emptyList(),
                    summary = "Weather data unavailable for $city. Check local forecast before travelling.",
                )
            }
        }

    fun getClimateInfo(location: String, month: Int): ClimateInfoResult {
        // Static climate database for common destinations.
        // In production: replace with a proper climate API or expand this table.
        val key = "${location.uppercase()}_$month"
        val data = CLIMATE_DATA[key] ?: CLIMATE_DATA["DEFAULT_$month"]!!

        return ClimateInfoResult(
            location       = location,
            month          = month,
            avgTempC       = data.avgTempC,
            avgRainyDays   = data.avgRainyDays,
            touristSeason  = data.season,
            summary        = data.summary,
        )
    }

    companion object {
        // Simplified climate reference data.
        // Keys: "LOCATION_MONTH" where month is 1-12.
        private data class ClimateData(
            val avgTempC: Double,
            val avgRainyDays: Int,
            val season: String,
            val summary: String,
        )

        private val CLIMATE_DATA = mapOf(
            "TURKEY_9"  to ClimateData(28.0, 3,  "Shoulder", "Warm and mostly sunny. Sea still warm for swimming (26°C). Less crowded than summer."),
            "TURKEY_10" to ClimateData(22.0, 5,  "Shoulder", "Pleasant 22°C. Ideal for sightseeing. Some rain possible but rarely heavy."),
            "TURKEY_11" to ClimateData(16.0, 8,  "Off-season","Cooler and quiet. Great for Istanbul culture. Beach resorts closing."),
            "ISTANBUL_9" to ClimateData(24.0, 5,  "Peak",    "Warm and pleasant. Busy but manageable. Evenings on the Bosphorus are magical."),
            "BALI_7"    to ClimateData(27.0, 2,  "Peak",     "Dry season peak. Perfect beach weather. Book accommodation well in advance."),
            "BALI_1"    to ClimateData(28.0, 18, "Off-season","Rainy season. Lush greenery but frequent heavy showers. Much cheaper prices."),
            "PARIS_5"   to ClimateData(18.0, 9,  "Shoulder", "Lovely spring weather. Cafes, gardens. Occasional showers — pack a light jacket."),
            "PARIS_7"   to ClimateData(25.0, 5,  "Peak",     "Warm and sunny. City is busy. Many locals on holiday — quieter neighborhoods."),
            "AMSTERDAM_4" to ClimateData(11.0, 11, "Shoulder","Tulip season. Mild but changeable. Perfect for cycling without summer crowds."),
            "DEFAULT_1" to ClimateData(15.0, 8,  "Variable", "Climate data not available. Recommend checking local sources."),
            "DEFAULT_6" to ClimateData(22.0, 6,  "Variable", "Climate data not available. Recommend checking local sources."),
            "DEFAULT_9" to ClimateData(19.0, 7,  "Variable", "Climate data not available. Recommend checking local sources."),
        )

        // Fallback for missing months
        private fun Map<String, ClimateData>.get(key: String): ClimateData? {
            return this.entries.firstOrNull { it.key == key }?.value
                ?: this.entries.firstOrNull { it.key.startsWith("DEFAULT_") }?.value
        }
    }
}

// OpenWeather API response shapes
data class OpenWeatherForecastResponse(val list: List<OpenWeatherSlot> = emptyList())
data class OpenWeatherSlot(
    val dt_txt: String,
    val main: OpenWeatherMain,
    val weather: List<OpenWeatherCondition>,
    val wind: OpenWeatherWind,
    val pop: Double = 0.0,            // probability of precipitation
)
data class OpenWeatherMain(val temp: Double, val humidity: Int)
data class OpenWeatherCondition(val main: String, val description: String)
data class OpenWeatherWind(val speed: Double)


// ============================================================
// GOOGLE PLACES CLIENT
// ============================================================

@Component
class GooglePlacesClient(
    private val httpClient: HttpClient,
    @Value("\${wayai.google.places-api-key}") private val placesApiKey: String,
    @Value("\${wayai.google.maps-api-key}")   private val mapsApiKey: String,
) {
    private val log = LoggerFactory.getLogger(GooglePlacesClient::class.java)

    fun searchPlaces(
        city: String,
        category: String,
        tags: List<String>,
        maxResults: Int,
    ): PlacesSearchResult = runBlocking {
        runCatching {
            val query    = buildQuery(city, category, tags)
            val response: GooglePlacesSearchResponse = httpClient.get(
                "https://maps.googleapis.com/maps/api/place/textsearch/json"
            ) {
                parameter("query",  query)
                parameter("key",    placesApiKey)
                parameter("type",   categoryToGoogleType(category))
                parameter("language", "en")
            }.body()

            val places = response.results.take(maxResults).map { result ->
                PlaceResult(
                    placeId          = result.place_id,
                    name             = result.name,
                    category         = category,
                    rating           = result.rating,
                    reviewCount      = result.user_ratings_total,
                    address          = result.formatted_address ?: result.vicinity ?: city,
                    latitude         = result.geometry.location.lat,
                    longitude        = result.geometry.location.lng,
                    priceLevel       = result.price_level,
                    imageUrl         = result.photos?.firstOrNull()?.let { buildPhotoUrl(it.photo_reference) },
                    tags             = result.types ?: emptyList(),
                    shortDescription = null,
                )
            }

            PlacesSearchResult(city = city, category = category, places = places)
        }.getOrElse { e ->
            log.error("Google Places search error for $city/$category", e)
            PlacesSearchResult(city, category, emptyList())
        }
    }

    fun getPlaceDetails(placeId: String): PlaceDetailsResult = runBlocking {
        runCatching {
            val response: GooglePlaceDetailsResponse = httpClient.get(
                "https://maps.googleapis.com/maps/api/place/details/json"
            ) {
                parameter("place_id", placeId)
                parameter("key",      placesApiKey)
                parameter("fields",   "place_id,name,editorial_summary,opening_hours,price_level,website,formatted_phone_number,photos")
                parameter("language", "en")
            }.body()

            val r = response.result
            PlaceDetailsResult(
                placeId                     = placeId,
                name                        = r.name,
                fullDescription             = r.editorial_summary?.overview,
                openingHours                = r.opening_hours?.weekday_text
                    ?.associate { line ->
                        val parts = line.split(": ", limit = 2)
                        parts.getOrElse(0) { "Mon" } to parts.getOrElse(1) { "Closed" }
                    } ?: emptyMap(),
                isOpenNow                   = r.opening_hours?.open_now,
                admissionPriceEur           = null,  // not in Places API, Claude infers from knowledge
                recommendedVisitDurationMin = null,  // Claude infers from category + size
                bestTimeToVisit             = null,
                insiderTip                  = null,
                websiteUrl                  = r.website,
                phoneNumber                 = r.formatted_phone_number,
            )
        }.getOrElse { e ->
            log.error("Google Place details error for $placeId", e)
            PlaceDetailsResult(placeId, "Unknown", null, emptyMap(), null, null, null, null, null, null, null)
        }
    }

    fun getTravelTime(origin: String, destination: String, city: String): TravelTimeResult =
        runBlocking {
            runCatching {
                val originQ      = "$origin, $city"
                val destinationQ = "$destination, $city"

                val response: GoogleDistanceMatrixResponse = httpClient.get(
                    "https://maps.googleapis.com/maps/api/distancematrix/json"
                ) {
                    parameter("origins",      originQ)
                    parameter("destinations", destinationQ)
                    parameter("mode",         "transit")
                    parameter("key",          mapsApiKey)
                    parameter("language",     "en")
                }.body()

                val element = response.rows.firstOrNull()?.elements?.firstOrNull()
                val transitMin = element?.duration?.value?.let { it / 60 }
                val distKm     = element?.distance?.value?.let { it / 1000.0 }

                TravelTimeResult(
                    origin          = origin,
                    destination     = destination,
                    walkingMinutes  = distKm?.let { (it / 5.0 * 60).toInt() },  // ~5km/h walk
                    transitMinutes  = transitMin,
                    taxiMinutes     = distKm?.let { (it / 30.0 * 60 + 5).toInt() }, // ~30km/h + wait
                    taxiCostEst     = distKm?.let { it * 1.5 },                  // rough $1.5/km
                    distanceKm      = distKm,
                )
            }.getOrElse { e ->
                log.error("Google Distance Matrix error", e)
                TravelTimeResult(origin, destination, null, null, null, null, null)
            }
        }

    // ----------------------------------------------------------
    // HELPERS
    // ----------------------------------------------------------

    private fun buildQuery(city: String, category: String, tags: List<String>): String {
        val tagStr = if (tags.isNotEmpty()) " ${tags.take(3).joinToString(" ")}" else ""
        return "$category$tagStr in $city"
    }

    private fun categoryToGoogleType(category: String): String = when (category.uppercase()) {
        "RESTAURANT"  -> "restaurant"
        "MUSEUM"      -> "museum"
        "BEACH"       -> "natural_feature"
        "PARK"        -> "park"
        "SHOPPING"    -> "shopping_mall"
        "NIGHTLIFE"   -> "bar"
        "SPA"         -> "spa"
        else          -> "tourist_attraction"
    }

    private fun buildPhotoUrl(ref: String): String =
        "https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=$ref&key=$placesApiKey"
}

// Google Places API response shapes
data class GooglePlacesSearchResponse(val results: List<GooglePlaceResult> = emptyList())
data class GooglePlaceResult(
    val place_id: String,
    val name: String,
    val formatted_address: String?,
    val vicinity: String?,
    val rating: Double?,
    val user_ratings_total: Int?,
    val price_level: Int?,
    val geometry: GoogleGeometry,
    val photos: List<GooglePhoto>?,
    val types: List<String>?,
)
data class GoogleGeometry(val location: GoogleLatLng)
data class GoogleLatLng(val lat: Double, val lng: Double)
data class GooglePhoto(val photo_reference: String)

data class GooglePlaceDetailsResponse(val result: GooglePlaceDetail)
data class GooglePlaceDetail(
    val name: String,
    val editorial_summary: GoogleEditorialSummary?,
    val opening_hours: GoogleOpeningHours?,
    val website: String?,
    val formatted_phone_number: String?,
)
data class GoogleEditorialSummary(val overview: String?)
data class GoogleOpeningHours(val open_now: Boolean?, val weekday_text: List<String>?)

data class GoogleDistanceMatrixResponse(val rows: List<GoogleDistanceRow> = emptyList())
data class GoogleDistanceRow(val elements: List<GoogleDistanceElement> = emptyList())
data class GoogleDistanceElement(val duration: GoogleDurationValue?, val distance: GoogleDurationValue?)
data class GoogleDurationValue(val value: Int)

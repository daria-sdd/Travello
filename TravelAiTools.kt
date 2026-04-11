package com.wayai.infrastructure.ai

import com.wayai.infrastructure.ai.clients.AmadeusClient
import com.wayai.infrastructure.ai.clients.GooglePlacesClient
import com.wayai.infrastructure.ai.clients.OpenWeatherClient
import dev.langchain4j.agent.tool.Tool
import dev.langchain4j.agent.tool.P
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Component
import java.time.LocalDate

// ============================================================
// AI TOOLS
// These are the "hands" of the AI agent.
// Claude decides when to call each tool based on context.
// Each method is exposed to Claude via @Tool annotation.
// ============================================================

@Component
class TravelAiTools(
    private val amadeusClient: AmadeusClient,
    private val weatherClient: OpenWeatherClient,
    private val placesClient: GooglePlacesClient,
) {
    private val log = LoggerFactory.getLogger(TravelAiTools::class.java)

    // ----------------------------------------------------------
    // FLIGHTS
    // ----------------------------------------------------------

    @Tool("""
        Search for available flights between two airports or cities.
        Use IATA codes when known (e.g. IST, SAW for Istanbul).
        Returns real flight offers with prices, airlines, and departure times.
        Always call this when the user wants flights or when you need to
        validate that a route is actually reachable.
    """)
    fun searchFlights(
        @P("Departure city or IATA airport code, e.g. 'Moscow' or 'SVO'")
        origin: String,

        @P("Destination city or IATA airport code, e.g. 'Istanbul' or 'IST'")
        destination: String,

        @P("Departure date in YYYY-MM-DD format")
        departureDate: String,

        @P("Return date in YYYY-MM-DD format, or empty string for one-way")
        returnDate: String = "",

        @P("Number of adult passengers")
        adults: Int = 1,

        @P("Travel class: ECONOMY, PREMIUM_ECONOMY, BUSINESS, FIRST")
        travelClass: String = "ECONOMY",

        @P("Maximum number of results to return, between 1 and 10")
        maxResults: Int = 5,
    ): FlightSearchResult {
        log.info("Tool: searchFlights $origin → $destination on $departureDate")
        return amadeusClient.searchFlights(
            origin       = origin,
            destination  = destination,
            departDate   = LocalDate.parse(departureDate),
            returnDate   = if (returnDate.isBlank()) null else LocalDate.parse(returnDate),
            adults       = adults,
            travelClass  = travelClass,
            maxResults   = maxResults,
        )
    }

    @Tool("""
        Find the cheapest months or date ranges to fly from one city to another.
        Use this when the user has flexible dates or when you want to suggest
        the best time to travel for budget reasons.
        Returns cheapest dates with prices for the next 6 months.
    """)
    fun findCheapestFlightDates(
        @P("Departure city or IATA airport code")
        origin: String,

        @P("Destination city or IATA airport code")
        destination: String,
    ): CheapestDatesResult {
        log.info("Tool: findCheapestFlightDates $origin → $destination")
        return amadeusClient.findCheapestDates(origin, destination)
    }

    @Tool("""
        Get flight inspiration: find the cheapest destinations to fly to
        from a given origin city. Use when the user does not know where
        they want to go, or says 'surprise me' or 'I want to travel but
        don't know where'. Returns top destinations sorted by price.
    """)
    fun findCheapestDestinations(
        @P("Departure city or IATA airport code")
        origin: String,

        @P("Approximate departure month in YYYY-MM format, or empty for any month")
        departureMonth: String = "",

        @P("Maximum budget per person in USD")
        maxBudget: Int = 2000,
    ): DestinationInspirationResult {
        log.info("Tool: findCheapestDestinations from $origin, budget $$maxBudget")
        return amadeusClient.findDestinationInspiration(origin, departureMonth, maxBudget)
    }

    // ----------------------------------------------------------
    // HOTELS
    // ----------------------------------------------------------

    @Tool("""
        Search for hotels in a city. Returns real hotels with current prices,
        ratings, amenities and availability. Use when building accommodation
        blocks in the travel plan. Prefer hotels near city center unless
        the user specified otherwise.
    """)
    fun searchHotels(
        @P("City name or IATA city code")
        city: String,

        @P("Check-in date in YYYY-MM-DD format")
        checkIn: String,

        @P("Check-out date in YYYY-MM-DD format")
        checkOut: String,

        @P("Number of adult guests")
        adults: Int = 1,

        @P("Budget tier: BUDGET (under 80/night), MEDIUM (80-200/night), LUXURY (200+/night)")
        budgetTier: String = "MEDIUM",

        @P("Maximum number of results")
        maxResults: Int = 5,
    ): HotelSearchResult {
        log.info("Tool: searchHotels in $city $checkIn → $checkOut")
        return amadeusClient.searchHotels(
            city       = city,
            checkIn    = LocalDate.parse(checkIn),
            checkOut   = LocalDate.parse(checkOut),
            adults     = adults,
            budgetTier = budgetTier,
            maxResults = maxResults,
        )
    }

    // ----------------------------------------------------------
    // WEATHER
    // ----------------------------------------------------------

    @Tool("""
        Get weather forecast for a city for specific dates.
        Use this to validate that weather matches user preferences
        (e.g., "not too hot", "beach weather", "no rain").
        Also use to add weather notes to each day in the plan.
        Returns temperature, conditions, rain probability.
    """)
    fun getWeatherForecast(
        @P("City name")
        city: String,

        @P("Start date in YYYY-MM-DD format")
        dateFrom: String,

        @P("End date in YYYY-MM-DD format")
        dateTo: String,
    ): WeatherForecastResult {
        log.info("Tool: getWeatherForecast $city $dateFrom → $dateTo")
        return weatherClient.getForecast(
            city     = city,
            dateFrom = LocalDate.parse(dateFrom),
            dateTo   = LocalDate.parse(dateTo),
        )
    }

    @Tool("""
        Get historical climate data for a city and month.
        Use this when the user has flexible dates and you want to recommend
        the best month to visit: "October in Turkey is 22°C and sunny".
        Returns average temperature, rainfall, and tourism season info.
    """)
    fun getClimateInfo(
        @P("City or country name")
        location: String,

        @P("Month number (1-12)")
        month: Int,
    ): ClimateInfoResult {
        log.info("Tool: getClimateInfo $location month=$month")
        return weatherClient.getClimateInfo(location, month)
    }

    // ----------------------------------------------------------
    // PLACES & ACTIVITIES
    // ----------------------------------------------------------

    @Tool("""
        Search for tourist attractions, restaurants, museums, beaches,
        markets, viewpoints and other points of interest in a city.
        Returns top places with ratings, photos, opening hours and tips.
        Use to fill activity blocks in each day of the travel plan.
    """)
    fun searchPlaces(
        @P("City name")
        city: String,

        @P("Category: SIGHTSEEING, RESTAURANT, MUSEUM, BEACH, MARKET, PARK, SHOPPING, NIGHTLIFE, SPA")
        category: String,

        @P("User's interest tags, e.g. 'history,architecture,local food'")
        tags: String = "",

        @P("Maximum number of results")
        maxResults: Int = 8,
    ): PlacesSearchResult {
        log.info("Tool: searchPlaces $category in $city")
        return placesClient.searchPlaces(
            city       = city,
            category   = category,
            tags       = tags.split(",").map { it.trim() }.filter { it.isNotBlank() },
            maxResults = maxResults,
        )
    }

    @Tool("""
        Get detailed information about a specific place including
        current opening hours, admission prices, visit duration,
        and insider tips. Call this after searchPlaces to get
        more detail for places you plan to include in the itinerary.
    """)
    fun getPlaceDetails(
        @P("Google Place ID from searchPlaces result")
        placeId: String,
    ): PlaceDetailsResult {
        log.info("Tool: getPlaceDetails $placeId")
        return placesClient.getPlaceDetails(placeId)
    }

    @Tool("""
        Calculate travel time between two points in a city.
        Use to check that daily itineraries are realistic —
        that the user has enough time to get between places.
        Returns walking, transit and taxi times.
    """)
    fun getTravelTime(
        @P("Origin place name or address")
        origin: String,

        @P("Destination place name or address")
        destination: String,

        @P("City context for disambiguation")
        city: String,
    ): TravelTimeResult {
        log.info("Tool: getTravelTime $origin → $destination in $city")
        return placesClient.getTravelTime(origin, destination, city)
    }
}

// ============================================================
// RESULT DATA CLASSES
// Structured output that Claude receives from each tool call.
// Simple, flat structure — easier for Claude to parse.
// ============================================================

data class FlightSearchResult(
    val found: Boolean,
    val offers: List<FlightOffer>,
    val searchSummary: String,           // human-readable summary for Claude
)

data class FlightOffer(
    val offerId: String,
    val airline: String,
    val flightNumber: String,
    val departureTime: String,           // ISO 8601
    val arrivalTime: String,
    val durationHours: Double,
    val stops: Int,
    val pricePerPerson: Double,
    val currency: String,
    val cabinClass: String,
    val baggageIncluded: Boolean,
    val seatsAvailable: Int?,
)

data class CheapestDatesResult(
    val origin: String,
    val destination: String,
    val cheapestOptions: List<CheapDateOption>,
)

data class CheapDateOption(
    val departureDate: String,
    val returnDate: String?,
    val pricePerPerson: Double,
    val currency: String,
)

data class DestinationInspirationResult(
    val origin: String,
    val destinations: List<InspirationDestination>,
)

data class InspirationDestination(
    val destination: String,
    val country: String,
    val priceFrom: Double,
    val currency: String,
    val departureDate: String?,
    val highlights: List<String>,        // ["beaches", "historic old town"]
)

data class HotelSearchResult(
    val found: Boolean,
    val hotels: List<HotelOffer>,
    val searchSummary: String,
)

data class HotelOffer(
    val hotelId: String,
    val name: String,
    val stars: Int,
    val rating: Double?,
    val reviewCount: Int?,
    val address: String,
    val distanceToCenterKm: Double?,
    val pricePerNight: Double,
    val totalPrice: Double,
    val currency: String,
    val breakfastIncluded: Boolean,
    val cancellationPolicy: String,
    val amenities: List<String>,
    val imageUrl: String?,
)

data class WeatherForecastResult(
    val city: String,
    val days: List<WeatherDay>,
    val summary: String,                 // "Sunny and warm, 24-28°C. No rain expected."
)

data class WeatherDay(
    val date: String,
    val tempMinC: Double,
    val tempMaxC: Double,
    val condition: String,               // "Sunny", "Partly Cloudy", "Rain"
    val rainProbability: Int,            // 0-100
    val humidity: Int,
    val windKmh: Double,
)

data class ClimateInfoResult(
    val location: String,
    val month: Int,
    val avgTempC: Double,
    val avgRainyDays: Int,
    val touristSeason: String,           // "Peak", "Shoulder", "Off-season"
    val summary: String,
)

data class PlacesSearchResult(
    val city: String,
    val category: String,
    val places: List<PlaceResult>,
)

data class PlaceResult(
    val placeId: String,
    val name: String,
    val category: String,
    val rating: Double?,
    val reviewCount: Int?,
    val address: String,
    val latitude: Double,
    val longitude: Double,
    val priceLevel: Int?,                // 1-4
    val imageUrl: String?,
    val tags: List<String>,
    val shortDescription: String?,
)

data class PlaceDetailsResult(
    val placeId: String,
    val name: String,
    val fullDescription: String?,
    val openingHours: Map<String, String>, // {"Monday": "09:00-18:00", ...}
    val isOpenNow: Boolean?,
    val admissionPriceEur: Double?,
    val recommendedVisitDurationMin: Int?,
    val bestTimeToVisit: String?,
    val insiderTip: String?,
    val websiteUrl: String?,
    val phoneNumber: String?,
)

data class TravelTimeResult(
    val origin: String,
    val destination: String,
    val walkingMinutes: Int?,
    val transitMinutes: Int?,
    val taxiMinutes: Int?,
    val taxiCostEst: Double?,
    val distanceKm: Double?,
)

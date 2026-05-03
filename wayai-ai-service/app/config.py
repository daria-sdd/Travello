from pydantic_settings import BaseSettings, SettingsConfigDict
from functools import lru_cache


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Anthropic
    anthropic_api_key: str
    anthropic_model: str = "claude-sonnet-4-20250514"
    anthropic_max_tokens: int = 8192
    anthropic_temperature: float = 0.7

    # Kafka
    kafka_bootstrap_servers: str = "localhost:9092"
    kafka_group_id: str = "wayai-ai-orchestrator"
    kafka_topic_route_generation: str = "route-generation-requests"

    # PostgreSQL (пишем результаты напрямую)
    database_url: str = "postgresql+asyncpg://wayai:wayai@localhost:5432/wayai"

    # Redis (для SSE pub/sub — публикуем прогресс, Kotlin читает)
    redis_url: str = "redis://localhost:6379/0"

    # External APIs
    amadeus_client_id: str
    amadeus_client_secret: str
    amadeus_base_url: str = "https://api.amadeus.com"

    google_places_api_key: str
    google_maps_api_key: str

    openweather_api_key: str

    # LangSmith (опционально — для трейсинга промптов)
    langchain_api_key: str = ""
    langchain_tracing_v2: bool = False
    langchain_project: str = "wayai"


@lru_cache
def get_settings() -> Settings:
    return Settings()

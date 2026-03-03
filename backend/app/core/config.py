from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    PROJECT_NAME: str = "AviQuest API"
    VERSION: str = "1.0.0"
    API_V1_PREFIX: str = "/api/v1"

    # Database
    DATABASE_URL: str = "sqlite+aiosqlite:///./aviquest.db"

    # JWT Auth
    SECRET_KEY: str = "change-me-in-production-use-openssl-rand-hex-32"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days

    # Game mechanics
    XP_LEVEL_BASE: int = 1000
    XP_LEVEL_EXPONENT: float = 1.4
    RARITY_WEIGHTS: dict[str, float] = {
        "common": 0.60,
        "uncommon": 0.25,
        "rare": 0.12,
        "legendary": 0.03,
    }
    RARITY_XP_MULTIPLIERS: dict[str, float] = {
        "common": 1.0,
        "uncommon": 1.5,
        "rare": 2.0,
        "legendary": 5.0,
    }

    model_config = {"env_file": ".env", "extra": "ignore"}


settings = Settings()

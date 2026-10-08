"""Request/response schemas for the auth feature."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

# Practical subset of active ISO-4217 currency codes (national currencies a user would
# plausibly register with). Excludes precious metals, IMF/bond units, and test codes (XAU, XDR,
# XTS, XXX, ...).
ISO_4217_CURRENCIES = frozenset(
    {
        "AED",
        "AFN",
        "ALL",
        "AMD",
        "ANG",
        "AOA",
        "ARS",
        "AUD",
        "AWG",
        "AZN",
        "BAM",
        "BBD",
        "BDT",
        "BGN",
        "BHD",
        "BIF",
        "BMD",
        "BND",
        "BOB",
        "BRL",
        "BSD",
        "BTN",
        "BWP",
        "BYN",
        "BZD",
        "CAD",
        "CDF",
        "CHF",
        "CLP",
        "CNY",
        "COP",
        "CRC",
        "CUP",
        "CVE",
        "CZK",
        "DJF",
        "DKK",
        "DOP",
        "DZD",
        "EGP",
        "ERN",
        "ETB",
        "EUR",
        "FJD",
        "FKP",
        "GBP",
        "GEL",
        "GHS",
        "GIP",
        "GMD",
        "GNF",
        "GTQ",
        "GYD",
        "HKD",
        "HNL",
        "HTG",
        "HUF",
        "IDR",
        "ILS",
        "INR",
        "IQD",
        "IRR",
        "ISK",
        "JMD",
        "JOD",
        "JPY",
        "KES",
        "KGS",
        "KHR",
        "KMF",
        "KPW",
        "KRW",
        "KWD",
        "KYD",
        "KZT",
        "LAK",
        "LBP",
        "LKR",
        "LRD",
        "LSL",
        "LYD",
        "MAD",
        "MDL",
        "MGA",
        "MKD",
        "MMK",
        "MNT",
        "MOP",
        "MRU",
        "MUR",
        "MVR",
        "MWK",
        "MXN",
        "MYR",
        "MZN",
        "NAD",
        "NGN",
        "NIO",
        "NOK",
        "NPR",
        "NZD",
        "OMR",
        "PAB",
        "PEN",
        "PGK",
        "PHP",
        "PKR",
        "PLN",
        "PYG",
        "QAR",
        "RON",
        "RSD",
        "RUB",
        "RWF",
        "SAR",
        "SBD",
        "SCR",
        "SDG",
        "SEK",
        "SGD",
        "SHP",
        "SLE",
        "SOS",
        "SRD",
        "SSP",
        "STN",
        "SVC",
        "SYP",
        "SZL",
        "THB",
        "TJS",
        "TMT",
        "TND",
        "TOP",
        "TRY",
        "TTD",
        "TWD",
        "TZS",
        "UAH",
        "UGX",
        "USD",
        "UYU",
        "UZS",
        "VES",
        "VND",
        "VUV",
        "WST",
        "XAF",
        "XCD",
        "XOF",
        "XPF",
        "YER",
        "ZAR",
        "ZMW",
        "ZWG",
    }
)


class UserRegister(BaseModel):
    """Registration payload: credentials plus the locale and currency chosen at signup."""

    email: str = Field(min_length=1, max_length=255)
    password: str = Field(min_length=1)
    display_name: str = Field(min_length=1, max_length=255)
    locale: Literal["fr", "en"]
    currency: str

    @field_validator("currency")
    @classmethod
    def _validate_currency(cls, value: str) -> str:
        code = value.upper()
        if code not in ISO_4217_CURRENCIES:
            raise ValueError(f"Unknown ISO-4217 currency code: {value}")
        return code


class UserLogin(BaseModel):
    """Login payload."""

    email: str
    password: str


class UserRead(BaseModel):
    """A user's public profile, as returned by the API."""

    model_config = ConfigDict(from_attributes=True)

    id: str
    email: str
    display_name: str
    locale: str
    currency: str
    created_at: datetime


class TokenResponse(BaseModel):
    """Response for register/login: the session token and the user's profile."""

    token: str
    user: UserRead


class RegisterResponse(TokenResponse):
    """Response for register: the session plus the recovery code, shown to the user once."""

    recovery_code: str


class PasswordReset(BaseModel):
    """Reset a forgotten password with the recovery code issued earlier."""

    email: str
    recovery_code: str = Field(min_length=1)
    new_password: str = Field(min_length=1)


class PasswordResetResponse(TokenResponse):
    """Response for a password reset: a fresh session and the replacement recovery code."""

    recovery_code: str


class RecoveryCodeRegenerate(BaseModel):
    """Re-confirm the password before replacing the recovery code."""

    password: str


class RecoveryCodeResponse(BaseModel):
    """A newly generated recovery code, shown to the user once."""

    recovery_code: str


class MeResponse(BaseModel):
    """Response for GET /auth/me."""

    user: UserRead

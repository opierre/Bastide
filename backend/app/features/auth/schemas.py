"""Request/response schemas for the auth feature."""

import re
from datetime import datetime
from typing import Annotated, Literal

from pydantic import AfterValidator, BaseModel, ConfigDict, Field, field_validator

from app.features.auth.models import AVATAR_MONOGRAM, AVATAR_PRESET_PREFIX

# The display name doubles as the username. No "@" is allowed, so a login identifier that holds
# one is an email and anything else is a display name.
DISPLAY_NAME_PATTERN = re.compile(r"[a-z0-9._-]{3,32}")


def _normalize_display_name(value: str) -> str:
    name = value.strip().lower()
    if DISPLAY_NAME_PATTERN.fullmatch(name) is None:
        raise ValueError(
            "Display name must be 3 to 32 characters: letters, digits, '.', '_' or '-'."
        )
    return name


#: The shortest password accepted when one is set: at registration, at reset, and by any later
#: password change. Login doesn't check it, so a password set before the rule still signs in.
PASSWORD_MIN_LENGTH = 12

#: Publishes the minimum in the OpenAPI schema while validation keeps ``min_length=1``: the
#: service enforces it, so a short password gets ``PASSWORD_TOO_SHORT`` in the error envelope
#: rather than FastAPI's default request-validation 422.
_PASSWORD_SCHEMA_EXTRA = {"minLength": PASSWORD_MIN_LENGTH}

# Stored lowercased, so lookups are case-insensitive by construction.
DisplayName = Annotated[str, AfterValidator(_normalize_display_name)]

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
    password: str = Field(min_length=1, json_schema_extra=_PASSWORD_SCHEMA_EXTRA)
    display_name: DisplayName
    locale: Literal["fr", "en"]
    currency: str

    @field_validator("email")
    @classmethod
    def _validate_email(cls, value: str) -> str:
        # Login tells an email from a display name by its "@".
        if "@" not in value:
            raise ValueError("Email must contain '@'.")
        return value

    @field_validator("currency")
    @classmethod
    def _validate_currency(cls, value: str) -> str:
        code = value.upper()
        if code not in ISO_4217_CURRENCIES:
            raise ValueError(f"Unknown ISO-4217 currency code: {value}")
        return code


class UserLogin(BaseModel):
    """Login payload: the identifier is either the email or the display name."""

    identifier: str = Field(min_length=1)
    password: str


class ProfileUpdate(BaseModel):
    """Change the caller's profile."""

    display_name: DisplayName


#: The preset avatars: the user's initials on a plate of this category slot
#: (`docs/design/09-settings.md` §Profil). The keys are the contract; the app's theme owns the
#: colours, so a preset follows the dark and light palettes as a category does.
AVATAR_PRESETS = frozenset({"cat1", "cat2", "cat3", "cat4", "cat5", "cat6"})


def _validate_avatar_default(value: str) -> str:
    if value == AVATAR_MONOGRAM:
        return value
    key = value.removeprefix(AVATAR_PRESET_PREFIX)
    if key == value or key not in AVATAR_PRESETS:
        raise ValueError(f"Avatar must be '{AVATAR_MONOGRAM}' or a known 'preset:<key>'.")
    return value


#: A default avatar: the monogram or one of the presets. A picture is set by uploading it.
AvatarDefault = Annotated[str, AfterValidator(_validate_avatar_default)]


class AvatarChoiceUpdate(BaseModel):
    """Choose a default avatar; replaces an uploaded picture, if there is one."""

    avatar: AvatarDefault


#: The app's theme: follow the OS, or force dark or light.
ThemePreference = Literal["system", "dark", "light"]


class ThemeUpdate(BaseModel):
    """Choose the app's theme."""

    theme: ThemePreference


class UserRead(BaseModel):
    """A user's public profile, as returned by the API."""

    model_config = ConfigDict(from_attributes=True)

    id: str
    email: str
    display_name: str
    locale: str
    currency: str
    #: `monogram`, `preset:<key>`, or `image` (fetched from `GET /auth/me/avatar`).
    avatar: str
    #: `system`, `dark` or `light`.
    theme: str
    created_at: datetime


class TokenResponse(BaseModel):
    """Response for register/login: the session token and the user's profile."""

    token: str
    user: UserRead


class RegisterResponse(TokenResponse):
    """Response for register: the session plus the recovery code, shown to the user once."""

    recovery_code: str


class PasswordReset(BaseModel):
    """Reset a forgotten password with the recovery code issued earlier.

    The identifier is either the email or the display name, as at login.
    """

    identifier: str = Field(min_length=1)
    recovery_code: str = Field(min_length=1)
    new_password: str = Field(min_length=1, json_schema_extra=_PASSWORD_SCHEMA_EXTRA)


class PasswordResetResponse(TokenResponse):
    """Response for a password reset: a fresh session and the replacement recovery code."""

    recovery_code: str


class RecoveryCodeRegenerate(BaseModel):
    """Re-confirm the password before replacing the recovery code."""

    password: str


class PasswordChange(BaseModel):
    """Change the password of a signed-in user, who confirms the current one first."""

    current_password: str
    new_password: str = Field(min_length=1, json_schema_extra=_PASSWORD_SCHEMA_EXTRA)


class RecoveryCodeResponse(BaseModel):
    """A newly generated recovery code, shown to the user once."""

    recovery_code: str


class MeResponse(BaseModel):
    """Response for GET /auth/me."""

    user: UserRead

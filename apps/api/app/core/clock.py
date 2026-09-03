from datetime import datetime, timezone


def utcnow() -> datetime:
    """Naive UTC datetime (matches SQLModel's default naive `DateTime` columns).

    Avoids the deprecated `datetime.utcnow()` while keeping comparisons with
    values already stored in the DB (also naive) well-defined.
    """
    return datetime.now(timezone.utc).replace(tzinfo=None)

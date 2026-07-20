"""F7 Controlled DM rules.

Pure helpers for the request lifecycle so the gating logic (duplicate
prevention, decline cooldown) unit-tests without a DB. The premise of F7 is
that first contact is STRUCTURED: a typed intent + pitch, accepted before any
free-form messaging opens, and no raw contact details are ever exposed.
"""

from datetime import datetime, timedelta, timezone

# After a decline, the sender cannot re-request the same person for this long.
DECLINE_COOLDOWN = timedelta(days=7)

# Request intent types (aligned with the profile intent taxonomy).
REQUEST_INTENT_TYPES = {"cofounder", "maintainer", "collaboration", "chat"}


def can_send(
    existing: list[dict], now: datetime | None = None
) -> tuple[bool, str | None]:
    """Decide whether a new request to the same recipient may be sent.

    ``existing`` is the sender→recipient history as [{state, updated_at}].
    Returns (allowed, human_reason_if_not).
    """
    now = now or datetime.now(timezone.utc)
    for request in existing:
        state = request.get("state")
        if state == "pending":
            return False, "You already have a pending request to this person"
        if state == "accepted":
            return False, "You already collaborate — use your conversation"
        if state == "declined":
            updated_at = request.get("updated_at")
            if updated_at is not None and now - updated_at < DECLINE_COOLDOWN:
                days_left = (DECLINE_COOLDOWN - (now - updated_at)).days + 1
                return False, (
                    f"They declined recently — you can try again in {days_left} day(s)"
                )
    return True, None

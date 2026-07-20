"""F5: turn a user's verified profile into the text we embed.

Pure functions only. The text deliberately uses de-identified, skill-bearing
fields (languages, topics, headline, role, intent) -- never names or contact
details -- per the PRD's privacy stance on embeddings.
"""

from app.db.models import Intent, User


def skill_terms(user: User) -> list[str]:
    """The individual skill terms used both for embedding and match reasons."""
    terms: list[str] = []
    profile = user.github_profile or {}
    for entry in profile.get("top_languages") or []:
        language = entry.get("language")
        if language:
            terms.append(language)
    terms.extend(topic for topic in (profile.get("topics") or []) if topic)
    linkedin = user.linkedin_profile or {}
    headline = linkedin.get("headline")
    if headline:
        terms.append(headline)
    return terms


def skill_text(user: User, intent: Intent | None = None) -> str:
    """Compose the sentence handed to the MiniLM encoder (ADR-0001)."""
    parts = [f"role: {user.primary_role}"]
    terms = skill_terms(user)
    if terms:
        parts.append("skills: " + ", ".join(terms))
    if intent is not None:
        parts.append(f"intent: {intent.intent_type.replace('_', ' ')}")
        if intent.note:
            parts.append(intent.note)
    return " | ".join(parts)

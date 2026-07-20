"""F5: plain-language credibility summary.

Renders the verified evidence as short prose so NON-TECHNICAL users (founders,
designers) can read a candidate without knowing what a fork is. Pure.
"""


def credibility_summary(
    github_login: str,
    primary_role: str,
    github_summary: dict | None,
    active_weeks: int,
    total_weeks: int,
    linkedin_profile: dict | None,
    avg_stars: float | None,
    review_count: int,
) -> tuple[str, list[str]]:
    """Return (summary paragraph, bullet highlights)."""
    highlights: list[str] = []
    sentences: list[str] = []

    sentences.append(f"@{github_login} is a {primary_role} on Builder Plaza.")

    if github_summary:
        repos = github_summary.get("public_repos") or 0
        stars = github_summary.get("stars") or 0
        languages = [
            entry.get("language")
            for entry in (github_summary.get("top_languages") or [])[:3]
            if entry.get("language")
        ]
        work = f"They have {repos} public project(s)"
        if stars:
            work += f" that earned {stars} star(s) from other developers"
        work += "."
        sentences.append(work)
        if languages:
            highlights.append("Works mainly with " + ", ".join(languages))
    else:
        sentences.append("They have not connected a GitHub account yet.")

    if total_weeks:
        if active_weeks >= total_weeks * 0.6:
            sentences.append(
                f"They shipped work in {active_weeks} of the last {total_weeks} weeks — "
                "a consistent, verifiable rhythm."
            )
        elif active_weeks > 0:
            sentences.append(
                f"They were active in {active_weeks} of the last {total_weeks} weeks."
            )
        else:
            sentences.append("No public activity in the recent weeks.")

    tenure = (linkedin_profile or {}).get("tenure_years")
    company = (linkedin_profile or {}).get("company")
    if tenure:
        line = f"{tenure} year(s) of professional experience"
        if company:
            line += f" (currently at {company})"
        highlights.append(line)

    if review_count and avg_stars is not None:
        highlights.append(
            f"Rated {avg_stars:.1f}★ by {review_count} past collaborator(s)"
        )
    else:
        highlights.append("No peer reviews yet — be their first collaboration")

    return " ".join(sentences), highlights

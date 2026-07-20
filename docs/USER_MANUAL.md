# Builder Plaza — User Manual

## Getting started

1. **Verify your work (Step 1)** — enter your public GitHub username and tap
   *Connect GitHub*. Your public repos, languages and recent activity are
   fetched live and become your verifiable footprint.
2. **Professional identity (Step 2)** — sign in with LinkedIn (Live mode) or
   pick a demo persona on the watermarked *Simulated* consent screen.
3. **Choose your view (Step 3)** — Builder, Collaborator or Founder. This
   sets your home lens; you can switch any time from Profile.

## The four tabs

- **Home** — your collaboration intent, your projects, and entry points to
  *Requests & messages* and the *Request market*.
- **Plaza** — toggle between **PROJECTS** (discover active project cards,
  filter by stage, search) and **GROWTH** (AI-summarised progress updates
  across all projects, filterable by owner role).
- **Match** — your engine-ranked matches. Every card explains **WHY** it was
  suggested; the mustard **EXPLORE** badge marks the exploration pick. Pull
  to refresh for a new round. *Credibility* opens a plain-language summary
  with links to the candidate's trust score and evidence.
- **Profile** — completeness bar with the 40/70 gates, trust score, verified
  activity & evidence, intent editor, role switch, avatar upload (tap your
  avatar), and the clearly-labelled *Simulated suite*.

## Projects & growth

- *＋ New project* → title, stage, needs, demo URL, team division, linked
  `owner/repo` repositories, screenshots (uploaded straight to S3).
- On your project's page, *Refresh growth* polls your linked repos for new
  GitHub events and posts a neutral AI summary to the Plaza growth feed.
  If nothing new happened, nothing is posted.

## Trust & evidence

- **Trust score** blends GitHub contribution, LinkedIn tenure, peer reviews
  and a (simulated, labelled) payment badge; each component shows its own
  score, weight and availability.
- **Verified activity** is your recent public GitHub event timeline;
  **Ownership evidence** shows a 12-week activity continuity chart and the
  roles you hold on your repositories. Nothing here is self-reported.

## Requests, chats and the market

- First contact is always a **structured request**: pick an intent, write a
  pitch (min 20 characters), send. Recipients accept, decline, or you can
  withdraw. A declined request enforces a 7-day cooldown.
- **Accepting opens the conversation** — the only way a chat exists.
  Messages refresh every 10 seconds. No emails or phone numbers are ever
  shown.
- The **Request market** lists maintainer postings (linked to repo-backed
  projects, with an access tier) and team-role postings (stage, tech stack
  and commitment are always present). *Apply* sends a structured request
  referencing the posting.

## Offline

If the network drops, the Plaza feeds and your profile stay readable from
the last successful sync, marked *OFFLINE · SHOWING CACHED FEED*.

## Demo accounts

After `python seed.py`, log in via dev-login as **bp-demo** (main demo
account, has a pending request in the inbox), or any of the 11 personas
(e.g. `torvalds`, `sindresorhus`, `gvanrossum`).

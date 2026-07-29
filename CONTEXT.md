# Builder Plaza — Ubiquitous Language and Claim Boundaries

This file defines the terminology used across code, documentation, the report,
and the demo. When another document conflicts with these definitions, update the
other document rather than introducing a new synonym.

## Implementation tiers

- **Live feature** — implemented with application logic and persisted or
  provider-backed data. It can be demonstrated end to end without hardcoded
  feature results.
- **Simulated feature** — an implemented UI interaction backed by local demo
  state or a stub response. It demonstrates a future workflow and is visibly
  labelled `SIMULATED`.
- **Fallback** — deterministic behaviour used when an optional provider is
  unavailable. A fallback is not evidence that the provider call succeeded.

Current boundary:

- **Live:** F1-F8 and F10.
- **Simulated:** F9 Sandbox, AI Shortlist, Agent Access, and Proof of Work.
- **Simulated component:** payment identity inside Trust Score.
- **Dual implementation:** LinkedIn has Live OIDC and an explicitly simulated
  path used for repeatable automated testing and demonstrations.

## Roles and identity

- **Builder** — creates Project Cards, links repositories, publishes project
  progress, declares collaboration intent, and can post maintainer roles.
- **Collaborator** — discovers projects and candidates, reads Match Reasons and
  credibility evidence, and initiates structured collaboration requests.
- **Founder** — publishes team roles and evaluates candidates using matching,
  Trust Score, and ownership evidence.
- **Primary Role** — the switchable `builder | collaborator | founder`
  preference stored on one user account. It changes the initial home emphasis,
  title, and accent colour inside the shared navigation shell. It is not an
  identity, ownership, or permission boundary.
- **Dual-Source Trust Gateway** — the ordered onboarding gate that connects
  GitHub, connects LinkedIn, and records the Primary Role.

## Product and collaboration terms

- **Project Card** — a builder-authored product-in-progress record containing a
  title, stage, needs, optional demo URL, team division, linked repositories,
  and private-S3-backed screenshots.
- **Intent Badge** — the current collaboration state: seeking a co-founder,
  seeking a maintainer, open to chat, or not open, with an optional note.
- **Growth Plaza** — the feed of product-progress summaries derived from recent
  GitHub repository activity.
- **Growth Post** — one stored Plaza update. Amazon Bedrock may generate the
  summary; a deterministic fallback is used when the model is unavailable.
- **Match Reason** — the human-readable explanation attached to every matching
  result. A raw score is not presented as a sufficient explanation.
- **Exploration Match** — the single candidate slot in a refreshed matching
  round selected from beyond the strongest alignment set and labelled
  `EXPLORE`.
- **Controlled DM** — contact that begins with a structured Collaboration
  Request. A Conversation opens only after acceptance.
- **Collaboration Request** — a request with intent, pitch, and optional project
  or posting context. At most one pending request may exist for the same ordered
  sender/recipient pair.
- **Conversation** — the post-acceptance message thread shared only by the two
  request participants.
- **Request Market** — the unified board of maintainer and team-role postings.
- **Role Posting** — either `maintainer`, which may use staged repository access,
  or `team_role`, which requires stage, technology stack, and commitment.

## Trust and evidence terms

- **Trust Score** — a transparent blend of GitHub contribution, LinkedIn tenure,
  peer review, and a visibly simulated payment-identity component.
- **Verified Activity Timeline** — chronological public GitHub events used as
  evidence rather than self-declared profile content.
- **Ownership Evidence** — repository roles and activity continuity derived from
  GitHub data to support project-ownership assessment.
- **Credibility Summary** — a concise explanation of candidate evidence used by
  the matching and controlled-contact journey.

## Data and security terms

- **Presigned upload** — an authenticated request obtains a short-lived S3 PUT
  URL, the client uploads bytes directly without a Builder Plaza JWT, and the
  API validates the object before registering its key.
- **Screenshot registration** — the backend checks project ownership, the
  project-specific key namespace, S3 existence, and the 5 MB object-size limit
  before storing the key.
- **Archive** — a soft delete. The record remains for relational consistency but
  is excluded from active discovery.
- **Current matching round** — active match rows returned by the latest refresh.
  Dismissed history is retained so a dismissed candidate does not resurface.

## Claims that must not be made

- Do not describe F9 as a production sandbox, autonomous agent system, AI hiring
  service, or cryptographic Proof-of-Work implementation.
- Do not describe the simulated payment-identity component as Stripe
  verification.
- Do not describe the Android emulator Monkey crawl as Firebase Robo Test.
- Do not claim that a Bedrock-generated summary was used when the deterministic
  fallback produced the stored Growth Post.
- Do not describe Primary Role switching as three separate accounts or three
  separate navigation systems.
- Do not publish exact test totals without checking the latest test/CI output;
  parameterised pytest cases can change the executed total.

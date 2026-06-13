# Project Guidelines

GroupGuard LFG is a local UI helper for World of Warcraft LFG and group management.

## Neutral rule policy

The addon must not target nationality, ethnicity, origin, religion, or personal characteristics.

Allowed rule examples:

- spam text;
- boost advertising;
- carry offers;
- sell messages;
- GDKP ads;
- repeated unwanted text patterns;
- specific character names or guild names configured by the user.

Language/script checks, when enabled, are only technical text signals and must not be presented as identity or nationality detection.

## Development rules

- Keep `GroupGuardLFGDB` as the only SavedVariables database.
- Do not reintroduce old addon databases.
- Keep LFG application decline separate from party/raid member removal.
- Avoid protected-action logic outside direct user actions.
- Use safe optional integration with Premade Groups Filter.
- Do not overwrite PGF functions.

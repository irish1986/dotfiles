# Asking the user

Every question to the user goes through the question picker: `AskUserQuestion` in Claude Code, `ask_user` in Copilot CLI. This holds when a skill prescribes its own format for questions, such as a markdown round: the skill decides what to ask, the picker is how it is asked.

- Offer choices. The recommended answer is the first option, its label ending in "(Recommended)"; the reasoning goes in the option descriptions.
- A round with more questions than one picker call takes goes out as consecutive picker calls, together making up the whole round.
- Plain text is for a question with no sensible choices to offer.

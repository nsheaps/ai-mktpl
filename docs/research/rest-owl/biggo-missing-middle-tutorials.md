# The "Missing Middle" in Tutorials and Instructions

## Sources

- **BigGo Finance - Developer Tutorials Leave Beginners Lost**: https://finance.biggo.com/news/202509220713_Developer_Tutorials_Too_Complex_for_Beginners
- **CG Cookie - Reliance on Tutorials**: https://cgcookie.com/community/6394-does-anyone-else-get-the-feeling-that-they-re-reliant-on-tutorials-for-everything-or-just-not-retaining-knowledge-in-general
- **DEV Community - Identifying Knowledge Gaps**: https://dev.to/bgord/how-do-i-identify-my-knowledge-gaps-and-learn-4mlc
- **ClickUp - What Is a Knowledge Gap**: https://clickup.com/blog/knowledge-gap/

## The Core Problem

Content exists for complete beginners ("Hello World") and for experts (advanced documentation), but there's a massive gap in the middle. The intermediate learner -- who knows the basics but can't build something from scratch -- is underserved.

## The Curse of Knowledge

Tutorial authors suffer from the **curse of knowledge**: the inability to remember what it was like not to know something. This causes them to:

- Skip steps that seem "obvious" to them
- Use jargon without explanation
- Assume prerequisite knowledge without stating it
- Write peer-to-peer communication disguised as beginner tutorials

## Key Observations

### Tutorials as Peer Communication

Many tutorials function like academic papers -- sharing discoveries among professionals who already understand the ecosystem. They're not actually teaching; they're showing off techniques to peers.

### The "Crumble" Effect

From CG Cookie: "That feeling when you're a beginner, a few months/years in and you've watched tutorials and learnt concepts, but when it comes to making something from scratch you just crumble."

This is the exact "rest of the owl" moment -- you can follow along but can't reproduce independently.

### Invisible Prerequisites

Theoretical knowledge gaps are particularly hard to identify. "It's usually hidden in a talk or a well written article or post." You discover what you didn't know by accident, not by systematic study.

### Two Principles for Bridging the Gap

1. **Repetition** of important information
2. **Explicit explanation** of assumed knowledge

## Relevance to Plugin Development

1. **AI doesn't have the curse of knowledge** -- it can be prompted to explain every intermediate step, state every assumption, and define every term. This is a fundamental advantage.
2. **A spec-generation plugin should detect and fill assumption gaps** -- when generating a plan, it should make implicit knowledge explicit.
3. **The "crumble" effect maps to the scaffolding problem** -- users can follow AI-generated code but can't modify or extend it. Better specs would help users understand _why_ the code is structured as it is.
4. **Systematic gap identification is a product feature** -- instead of discovering gaps by accident, a plugin could analyze what the user knows (from their prompt/context) and proactively explain what they'll need to know.

## Criticism

- Not all knowledge gaps can be bridged by text. Some require practice, experimentation, and failure.
- Over-explaining everything creates information overload and can be patronizing to experienced users.
- The "missing middle" is partly a supply problem (hard to write good intermediate content) and partly a demand problem (people want shortcuts, not thorough explanations).

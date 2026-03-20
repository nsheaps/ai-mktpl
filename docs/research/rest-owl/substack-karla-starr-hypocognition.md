# Karla Starr: Hypocognition and the Owl-Drawing Problem

## Source
- **Karla Starr - "Draw the Rest of the Fucking Owl"**: https://karlastarr.substack.com/p/draw-the-rest-of-the-fucking-owl
- **Ruminare Substack**: https://ruminare.substack.com/p/draw-the-rest-of-the-owl

## Core Concept: Hypocognition

Hypocognition is "when we don't know what we don't know." People in dominant/privileged social groups remain oblivious to their advantages because they've never experienced the structural barriers others face. "Everyone is blind to their own privilege; we only see what's been difficult for us."

## The Brad Pitt Problem

Central metaphor: If an exceptionally attractive person wrote a dating guide with two steps ("go somewhere women are" then "smile"), it would sell millions despite being useless to most people. The author lacks awareness that his experience operates on a fundamentally different curve.

This is the "draw the rest of the owl" distilled to its essence -- the expert's instructions work for the expert because of invisible advantages, not because the instructions are actually sufficient.

## Incomplete Advice from Expertise

Starr critiques productivity gurus like James Clear, whose suggestions assume:
- Full schedule autonomy
- No caregiving responsibilities
- Neurotypical brains
- Support systems (assistants, stay-at-home spouses)

These frameworks treat specific privileges as universal defaults.

## The 11-Step Owl

Starr's own path to productivity required **eleven steps** -- including therapy, getting sober, managing ADHD, and escaping codependent patterns -- none of which are mentioned in simplified productivity guides.

The "two-step owl" guides present the illusion that success is simple. The actual owl requires many invisible prerequisites.

## The Shame Consequence

Simplified answers create shame: "We feel like something's wrong with us when we can't just 'draw the rest of the owl.'" Rather than recognizing incomplete advice, people internalize failure.

Starr's conclusion: "Don't feel ashamed if simple answers don't cut it. Feel human."

## Relevance to Plugin Development

1. **The "invisible 11 steps" is the exact problem a spec-generation plugin solves.** When someone says "build me an app that does X," there are dozens of invisible prerequisites (auth, deployment, error handling, testing, security) that experts take for granted.

2. **A good plugin should surface invisible assumptions**, not just generate code. It should ask: "You said 'build a REST API.' Are you also thinking about authentication? Rate limiting? Error handling? Logging? Deployment?"

3. **The shame dynamic is a UX insight**: Users who struggle with AI-generated code may feel inadequate rather than recognizing the tool's output was incomplete. A plugin that acknowledges complexity and provides graduated steps reduces this shame.

4. **Hypocognition maps directly to prompt engineering**: Users can't prompt for what they don't know they need. A plugin that proactively expands scope based on domain knowledge addresses this.

## Criticism

- Starr's argument, while compelling, is primarily about social/structural privilege rather than technical knowledge gaps. The mapping to software development is an analogy, not a direct parallel.
- Not all "missing steps" are invisible privileges -- some are genuinely hard-to-transfer tacit knowledge that even the most detailed spec can't capture.
- There's a risk of over-patternalizing: assuming users need everything spelled out can be condescending to experienced developers.

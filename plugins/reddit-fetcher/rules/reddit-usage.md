# Reddit Content Usage Guidelines

## Content Quality Skepticism

Reddit content is user-generated and unverified. When using fetched Reddit data:

- **Never treat Reddit comments as authoritative sources.** They are opinions, anecdotes, and sometimes misinformation.
- **Cross-reference claims** with official documentation or reputable sources before acting on them.
- **Upvote count does not equal correctness.** Popular answers can be wrong; low-scored answers can be right.
- **Check post age.** Technical advice from years ago may be outdated.
- **Watch for sarcasm and jokes.** Reddit threads frequently contain humor that reads as sincere advice.

## Fetching Best Practices

- Save fetched Reddit content to a file before analysis (per bash-scripting rules).
- Cite Reddit sources with full permalink URLs when referencing content.
- Respect rate limits -- do not fetch more than needed.
- Use subreddit-scoped search before broad search for more relevant results.
- Prefer `top` sort with a time filter for finding well-regarded content on a topic.

## When to Use Reddit Fetching

- Researching community sentiment about a tool, library, or approach
- Finding real-world experience reports and gotchas
- Discovering solutions to obscure errors (Reddit threads often surface in search results)
- Gauging adoption and popularity of technologies

## When NOT to Use Reddit Fetching

- As a substitute for official documentation
- For security-sensitive configuration (Reddit advice may be insecure)
- For legal, medical, or financial guidance
- When the information is available from a more authoritative source

# Doc Excerpt

**Definition:** A small reusable chunk of documentation that's included via reference (e.g. `@-reference` or include-syntax) into multiple host documents. Excerpts let multiple docs share canonical wording for the same concept without duplicating it.

**Naming choice (excerpt vs. partial):** This codebase uses **"excerpt"** consistently. "Partial" is a common alternative (especially in templating systems), but excerpt better conveys "a piece extracted from a larger thing for inclusion elsewhere" — partials sometimes imply a fragment that's incomplete on its own. Apply "excerpt" across all skill/rule/doc cross-references going forward.

**Example use:** A drilldown skill `@-references` an excerpt about how to use drilldown skills, so each drilldown skill stays terse but the explanation lives in one place.

**See also:** Supplementary Documentation.

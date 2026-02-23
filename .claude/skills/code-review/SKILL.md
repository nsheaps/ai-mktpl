<!--
TODO: compare this to the code review skill in scm-utils
-->

/review the PR for simplicity, flexibility, usability, documentation and comments (and associated discoverability), security concerns, proper matching of repo patterns/proper introduction of new patterns, adherence to best practices, and general quality assurance and engineering. 

Make sure to factor in 

* PR title and body, commit messages, commit history, the commit history relation to it's base branch. 



Launch a run_in_background:true Task sub-agent (do not launch Teammates) for each to evaluate the change in each category and produce a score 0/100 and a short paragraph explaining the score. 

All agents should

* include many references (to inside the codebase, references to other repos in the org or internet in general, documentation, wikis, slack links, workflow links, etc) to support the claims in their detailed review.

* write their final report to .claude/pr-reviews/$org/$repo/$prNumber/$epochTimePassedToAgentsFromParentSessionForConsistency/$category/REPORT.md

Each agent may also 

* leave inline comments to be left in the PR.

*  leave additional supporting documentation for additional reference from their overall REPORT.md.



When all agents complete, review each report, comparing results with each review to get the whole picture, and create one overall report. This detailed report should be available as an additional artifact within the branch, as well as the overall report. At minimum, give the scores back to the user, formatted in a table, using emojis to call out worrysome values (🚨 for <70%, ⚠️ for <85%, ✅ for above that). For non-blocking review comments, prefix the comment with 🔕, and for info only comments (like explicit things that were validated and checked as part of the review) use ℹ️. If the review is >95% overall, keep the final review to be just the table. If there are any categories with a ⚠️, the maximum overall score is 94%. Try to limit any "additional validation" comments in the final PR if everything is good, except for mission critical things. The references built by the sub-agents should still track them however, and be verbose, even if to a fault (but still validate-able and correct).

If you are running in an agentic mode, where you are empowered to leave comments yourself, you should leave in-line comments in the review as individual, comment-only reviews, then a final review at the end, so that future reviews don't need to re-post in-line comments. Hide details in your final review using github markdown's <summary> element, and use shields.io tags to show the review scoring concisely (coloring appropriately to match the emoji).

Otherwise, or if you are running in an interactive cli, provide links to the files on github or locally so the user can open it themselves.

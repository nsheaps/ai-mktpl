---
name: update-licenses-on-dep-change
enabled: true
event: file
action: warn
conditions:
  - field: file_path
    operator: regex_match
    pattern: package\.json$
  - field: new_text
    operator: regex_match
    pattern: (dependencies|devDependencies)
---

**Dependencies changed — check license compliance!**

When `package.json` dependencies change, verify that all new or updated
packages have compatible licenses (MIT, ISC, BSD, Apache-2.0, etc.).

Run `npx license-checker --summary` or `bun pm ls` to review.

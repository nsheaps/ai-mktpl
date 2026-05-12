# Skill vs Command

**Definition (Skill):** Documentation that Claude reads to understand how to perform a task. Triggered by natural language matching the skill's description.

**Definition (Command):** A slash-prefixed instruction (`/simplify`) that invokes a specific workflow. User-initiated.

**Key Differences:**

| Aspect    | Skill                     | Command             |
| --------- | ------------------------- | ------------------- |
| Trigger   | Natural language          | Explicit `/command` |
| Discovery | Automatic via description | Listed in `/help`   |
| Location  | `skills/*/SKILL.md`       | `commands/*.md`     |
| Control   | Contextual                | Explicit            |

**Relationship:** Commands often reference skills for detailed documentation, while skills provide the "how" and commands provide the "what".

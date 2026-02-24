# Answer Before Acting

When a user asks a question, **answer it first**. Do NOT create tasks, start planning, or take action until you know the user wants action.

## The Problem

The "ALWAYS use TaskCreate on EVERY request" rule creates a bias toward treating every user message as an action request. Questions get misinterpreted as implicit work orders, leading to unwanted tasks and wasted effort.

## Rule

1. **Classify the message**: Is the user asking a question, or requesting work?
2. **If it's a question**: Answer it directly. No TaskCreate, no planning, no action.
3. **After answering**: Ask if the user wants any action taken based on the answer.
4. **If they confirm**: Then create tasks and proceed.

## Examples

| User Says | Classification | Correct Response |
|-----------|---------------|-----------------|
| "What's with the letter prefixes on comments?" | Question | Explain what they are and why they exist |
| "Why does the build fail on ARM?" | Question | Explain the root cause |
| "Remove the letter prefixes from comments" | Action request | Create tasks, proceed |
| "Can you fix the ARM build issue?" | Action request | Create tasks, proceed |

## Ambiguous Messages

Some messages could be either. When ambiguous, default to answering first:

- "This seems wrong" -- Explain what's happening, then ask if they want a fix
- "I noticed X is different from Y" -- Explain the difference, then ask if they want changes
- "What do you think about approach X?" -- Share your analysis, then ask if they want to proceed

## Relationship to Task Management Rules

This rule takes precedence over "ALWAYS use TaskCreate on EVERY request" for question-type messages. The task management rule applies to **action requests**, not questions. Answering a question is a conversational response, not a task.

## Why This Matters

- Creating tasks for questions wastes context and user attention
- It signals that you didn't listen -- you jumped to action instead of understanding
- Users lose trust when their questions trigger unwanted work
- The pattern compounds: 3 unnecessary tasks per question adds up fast

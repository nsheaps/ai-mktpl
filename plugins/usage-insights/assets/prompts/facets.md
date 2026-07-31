Analyze the Claude Code session summaries below and classify each session across a fixed set of facets. These per-session facets are aggregated into the charts in the final report.

RESPOND WITH ONLY A VALID JSON OBJECT of the shape:

{
  "sessions": [
    {
      "session_id": "the session id you were given",
      "session_type": "one of the SESSION TYPE enum",
      "request_types": ["one or more of the REQUEST TYPE enum"],
      "capabilities_that_helped": ["zero or more of the CAPABILITY enum"],
      "friction_types": ["zero or more of the FRICTION TYPE enum"],
      "satisfaction": "one of the SATISFACTION enum",
      "outcome": "one of the OUTCOME enum",
      "helpfulness": "one of the HELPFULNESS enum"
    }
  ]
}

Use ONLY the enum values below — do not invent new categories.

## SESSION TYPE
single_task, multi_task, iterative_refinement, exploration, quick_question

## REQUEST TYPE
debug_investigate, implement_feature, fix_bug, write_script_tool, refactor_code, configure_system, create_pr_commit, analyze_data, understand_codebase, write_tests, write_docs, deploy_infra, warmup_minimal

## CAPABILITY (what helped most)
fast_accurate_search, correct_code_edits, good_explanations, proactive_help, multi_file_changes, handled_complexity, good_debugging

## FRICTION TYPE
misunderstood_request, wrong_approach, buggy_code, user_rejected_action, claude_got_blocked, user_stopped_early, wrong_file_or_location, excessive_changes, slow_or_verbose, tool_failed, user_unclear, external_issue

## SATISFACTION
frustrated, dissatisfied, likely_satisfied, satisfied, unsure, neutral, delighted

## OUTCOME
fully_achieved, mostly_achieved, partially_achieved, not_achieved, unclear_from_transcript

## HELPFULNESS
unhelpful, slightly_helpful, moderately_helpful, very_helpful, essential

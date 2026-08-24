🔴 FAILED — morning-pipeline cascade (07:39–07:44 UTC today):
• morning-pipeline chain: failed 2026-08-24 07:44 UTC
• morning-brief: failed 2026-08-24 07:43 UTC (1 consecutive)
• market-context-refresh: failed 2026-08-24 07:39 UTC (2 consecutive)
• token-movers: failed 2026-08-24 07:39 UTC (1 consecutive)

All four share the same api_error_status error signature — likely a transient Claude API error during the 07:00 UTC batch run. No morning brief delivered today. Next retry: token-alert / token-movers at 12:00 UTC.

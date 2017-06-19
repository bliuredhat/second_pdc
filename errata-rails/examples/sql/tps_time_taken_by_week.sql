--
-- Show average time to "finished" for TPS jobs, broken down by week,
-- based on the started time. The idea is to show historical trends
-- and to get some metrics to monitor TPS scheduling improvements.
--
-- See Bug 1207866.
--
-- There are a bunch of caveats/limitations such as:
-- * For waived jobs the time is based on human interaction.
-- * Not started jobs are never finished so they don't have a time
--   (but you can see how many there were).
-- * Jobs change state, eg NOT_STARTED -> BUSY -> {GOOD,BAD}. We don't see
--   any details about the time in each state.
--
-- Example usage (will write a csv file to /tmp):
--   rake debug:sql_examples:export SQL=examples/sql/tps_time_taken_by_week.sql
--
-- Example usage (display on stdout):
--   rake debug:sql_examples:run SQL=examples/sql/tps_time_taken_by_week.sql Y=1
--
SELECT
  AVG(TIMESTAMPDIFF(SECOND, started, finished)) AS avg_time_in_seconds,
  COUNT(*) AS job_count,
  DATE_FORMAT(started, "%Y.w%u") week_number,
  -- DATE_FORMAT(started, "%Y.%m") month,
  tpsstates.state
FROM
  tpsjobs
  JOIN tpsstates ON tpsjobs.state_id = tpsstates.id
GROUP BY
  DATE_FORMAT(started, "%Y.w%u"),
  -- DATE_FORMAT(started, "%Y.%m"),
  tpsstates.state

module ExternalTests
  module Ccat
    def use_ccat?
      # If there are any CCAT results, then we know CCAT is applicable. This is intended
      # to cover cases where ET didn't expect CCAT results but they were received anyway,
      # such as:
      # - CCAT manually triggered on errata older than Settings.ccat_start_time
      # - Advisory doesn't support CDN, but was copied by the RHN -> CDN sync process
      #   outside of ET, so it was nevertheless tested by CCAT
      if current_external_test_runs_for(ExternalTestType.get('ccat').with_related_types).any?
        return true
      end

      # If there are no results yet, the workflow must use CCAT and the advisory must have
      # some CDN content
      unless requires_external_test?(:ccat) && has_cdn?
        return false
      end

      # If the advisory isn't shipped/dropped yet, then we expect to receive results
      if is_open_state?
        return true
      end

      # (Some old errata do not store state transition records)
      current_state_time = current_state_index.try(:updated_at) || '2010-01-01'.to_datetime

      # The advisory is already shipped (or dropped).  Expect CCAT results only
      # if this happened after the defined CCAT start time.  (Prevents CCAT from
      # being displayed for errata which existed prior to CCAT enablement)
      current_state_time > Settings.ccat_start_time
    end
  end
end

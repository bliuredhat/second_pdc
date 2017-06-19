#
# Have to prefix all these methods in case we have other types
# of external test run. (Not sure how to do this better other than
# to convert back to using STI for external test runs).
#
module ExternalTestRunCovscan
  extend ActiveSupport::Concern

  #
  # Ask a scan to reschedule itself.
  # Used in external_tests_controller.
  #
  def covscan_reschedule!
    new_covscan_run = CovscanCreateObserver.create_covscan_run_maybe(self.get_errata_brew_mapping)
    update_attribute(:superseded_by, new_covscan_run)
    self.make_inactive!
  end

  #
  # Update scan status.
  # Used in the qpid listener and also in
  # CovscanCreateObserver.update_covscan_test_run_state
  #
  def covscan_status_update(new_scan_state)
    old_scan_state = self.external_status
    self.update_attributes(:external_status => new_scan_state, :status => covscan_map_external_status(new_scan_state))

    # Covscan can decide to restart a scan that was initially classified
    # as INELIGIBLE or ERROR. When that happens we need to clear the message
    # since it's no longer applicable. (Currently the message is only set when
    # a scan is created and it's ERROR or INELIGIBLE).
    if %w[ERROR INELIGIBLE].include?(old_scan_state) && new_scan_state != old_scan_state
      self.update_attributes(:external_message => nil)
    end
  end

  #
  # We need PASSED and WAIVED to be consistent across all test types since
  # they are specified in ExternalTestRun.passing_statuses and used to
  # determine if is test run is considered to be passed or not.
  #
  # For Covscan the status names are the same, so this method doesn't do
  # anything. But keep it to show intent (and as an example for future
  # external tests).
  #
  def covscan_map_external_status(external_status)
    case external_status
    when 'PASSED'; 'PASSED'
    when 'WAIVED'; 'WAIVED'
    else external_status
    end
  end
end

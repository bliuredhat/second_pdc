require 'message_bus/send_message_job'

module ExternalTestRunCcat
  extend ActiveSupport::Concern

  #
  # Ask a scan to reschedule itself.
  # Used in external_tests_controller.
  #
  def ccat_reschedule!
    # The TARGET is currently hard coded due to the fact that all ccat runs are
    # testing against the cdn-live pub target
    MessageBus.send_message(
      { 'ERRATA_ID' => errata.id.to_s,
        'JIRA_ISSUE_ID' => issue_url,
        'TARGET' => 'cdn-live',
      },
      'ccat.reschedule_test'
    )
  end
end

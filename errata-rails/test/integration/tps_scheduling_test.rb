require 'test_helper'

class TpsSchedulingTest < ActionDispatch::IntegrationTest
  test "warn user if TPS jobs do not have valid TPS streams" do
    auth_as admin_user
    # Pick a z-stream release erratum
    z_stream_erratum = Errata.find(19829)

    # This erratum will create the following 6 TPS jobs:
    # ["7Server-7.1.Z", "RHEL-7.1-Z-Server"]
    # ["7Server-7.1.Z", "RHEL-7.1-Z-Server"]
    # ["7Client-7.1.Z", "RHEL-7-Main-Client"]
    # ["7Server-7.1.Z", "RHEL-7.1-Z-Server"]
    # ["7ComputeNode-7.1.Z", "RHEL-7-Main-ComputeNode"]
    # ["7Workstation-7.1.Z", "RHEL-7-Main-Workstation"]

    # Manipulate 2 errors by deleting and deactivating 2 TPS streams.
    streams = []
    ['RHEL-7-Main-Client', 'RHEL-7-Main-ComputeNode'].each do |name|
      tps_stream = TpsStream.get_by_full_name(name)[0]
      assert_not_nil tps_stream, "Possible fixture error: Could not find TPS stream '#{name}'"
      streams << tps_stream
    end
    streams[0].destroy
    streams[1].update_attributes(:active => false)

    expected_warnings = {
      'RHEL-7.1-Z-Client' => "TPS stream 'RHEL-7.1-Z-Client' not found",
      'RHEL-7-Main-ComputeNode' => "TPS stream 'RHEL-7-Main-ComputeNode' is disabled",
    }

    pass_rpmdiff_runs(z_stream_erratum)
    z_stream_erratum.change_state!('QE', admin_user)

    visit "/tps/errata_results/#{z_stream_erratum.tps_run.id}"
    within(".bug_list") do
      all("tr").each_with_index do |tr, row|
        # Skip table header
        next if row == 0
        tps_stream = tr.find(".tps-stream").text.strip
        icon = tr.find('.tps-valid img')
        if warning_message = expected_warnings[tps_stream]
          # Should show alert icon if errors are detected
          assert_match(/icon_alert/, icon[:src], 'Alert icon not found.')
          popover = tr.find('.tps_error')
          # Check the popover title
          assert_equal("This job might not start due to the error/s below:", popover["data-original-title"])
          # Check the popover content
          assert_match(warning_message, popover["data-content"])
        else
          # Should show a tick icon otherwise
          assert_match(/icon_yes/, icon[:src], 'Yes icon not found.')
        end
      end
    end
  end
end

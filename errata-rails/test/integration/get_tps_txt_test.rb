require 'test_helper'

class GetTpsTxtTest < ActionDispatch::IntegrationTest

  def setup
    # Pick an advisory with a TPS run from our fixture data
    @errata = TpsRun.last.errata

    # Make sure it really does have a tps run and some jobs
    assert @errata.tps_run.present?
    assert @errata.tps_run.tps_jobs.any?
  end

  # See Bug 923404
  test "get_tps_txt trailing new line" do
    Settings.enable_tps_cdn = false
    # Don't need to auth since this is routed to the noauth controller
    visit "/errata/get_tps_txt/#{@errata.id}"
    response = page.source
    # Trailing new line is present?
    assert_match /\n$/, response, "No trailing newline for get_tps_txt"

    # Bonus sanity checks
    assert_match /^text\/plain/, page.response_headers['Content-Type'], "Unexpected content type in get_tps_txt"
    assert_equal @errata.tps_run.tps_txt_output, response, "Unexpected result for get_tps_txt"
    assert_equal @errata.tps_run.tps_txt_queue_entries.count, response.lines.count, "Incorrect number of lines in get_tps_txt"
    assert_equal 10, response.lines.first.split(",").length, "Unexpected number of fields in get_tps_txt line"
  end

  test "get_tps_txt with tps stream" do
    Settings.enable_tps_cdn = true
    visit "/errata/get_tps_txt/#{@errata.id}"
    response = page.source
    # Additional 2 columns which are 'Config' column(cdn|rhn) and Tps stream column
    assert_equal 12, response.lines.first.split(",").length,
                 "Unexpected number of fields in get_tps_txt line #{response.lines.first}"
  end

  # Want to check empty response when there is no tps run
  test "get_tps_txt empty response" do
    # Pick one with no tps run
    errata = Errata.new_files.last
    assert_nil errata.tps_run
    visit "/errata/get_tps_txt/#{errata.id}"
    assert_equal "", page.source, "Did not get empty string for empty response"
    assert_match /^text\/plain/, page.response_headers['Content-Type'], "Unexpected content type in get_tps_txt"
  end

end

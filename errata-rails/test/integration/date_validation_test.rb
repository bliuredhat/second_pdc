require 'test_helper'

class DateValidationTest < ActionDispatch::IntegrationTest

  setup do
    @errata = Errata.new_files.first
    assert_nil @errata.release_date
    assert_nil @errata.publish_date_override
    auth_as devel_user
  end

  def update_date(date_text, opts={})
    date_container = opts[:date_container]
    date_field = opts[:date_field]
    radio_choice = opts[:disabled] ? 'off' : 'on'
    visit "/errata/edit/#{@errata.id}"
    page.find("##{date_container} input[value=#{radio_choice}]").set(true)
    fill_in "advisory_#{date_field}", :with=>date_text
    click_button 'Preview >'
  end

  def update_embargo_date(date_text, opts={})
    update_date(date_text, {:date_container=>'embargo_date', :date_field=>'release_date'}.merge(opts))
  end

  def update_release_date(date_text, opts={})
    update_date(date_text, {:date_container=>'release_date', :date_field=>'publish_date_override'}.merge(opts))
  end

  test "good dates update okay" do
    update_embargo_date('2013-Nov-01')
    assert page.first('h1').has_content?("Preview Changes")
    click_button 'Save Errata'
    assert_equal DateTime.parse('2013-Nov-01'), @errata.reload.release_date

    update_release_date('2013-Nov-02')
    assert page.first('h1').has_content?("Preview Changes")
    click_button 'Save Errata'
    assert_equal DateTime.parse('2013-Nov-02'), @errata.reload.publish_date_override
  end

  test "bad dates fail" do
    update_embargo_date('2013-Mov-01')
    assert page.has_content?("Embargo date '2013-Mov-01' is not a valid date.")
    assert_nil @errata.reload.release_date

    update_release_date('2013-Mov-02')
    assert page.has_content?("Release date '2013-Mov-02' is not a valid date.")
    assert_nil @errata.reload.publish_date_override
  end

  test "disabled radio button works as it should" do
    update_embargo_date('2013-Mov-01', :disabled=>true)
    assert page.first('h1').has_content?("Preview Changes")
    click_button 'Save Errata'
    assert_nil @errata.reload.release_date

    update_release_date('2013-Mov-02', :disabled=>true)
    assert page.first('h1').has_content?("Preview Changes")
    click_button 'Save Errata'
    assert_nil @errata.reload.publish_date_override
  end

end

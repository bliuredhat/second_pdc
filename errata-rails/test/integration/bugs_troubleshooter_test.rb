require 'test_helper'

class BugsTroubleshooterTest < ActionDispatch::IntegrationTest

  def view_bug(bug_id)
    auth_as devel_user
    visit "/bugs/troubleshoot"
    fill_in 'bug_id', :with => bug_id
    click_on 'View Bug'
  end

  #
  # See Bug 962500
  #
  test "troubleshooter indicates empty approved component list" do
    bug = Bug.last
    release = Release.find_by_name('RHEL-6.3.0')
    bug.update_attribute(:flags, "#{release.name.downcase}+")
    view_bug(bug.id)
    assert page.has_content?('approved component list for RHEL-6.3.0 is currently empty')
  end

  test "troubleshooter with unknown bug number" do
    view_bug(1)
    assert page.has_content?("The bug 1 doesn't exist in Errata Tool")
  end

  test "troubleshooter with bug without release" do
    view_bug(Bug.first.id)
    assert page.has_content?("can't find release for release flag")
  end

  test "no activity logs" do
    view_bug(Bug.first.id)
    assert page.has_content?("No activity has been recorded for this bug.")
  end

  test "activity logs" do
    bug = Bug.first
    bug.info "Test log 1"
    bug.warn "Test log 2"
    view_bug(bug.id)
    assert page.has_content?("Test log 1")
    assert page.has_content?("Test log 2")
  end

  test "activity logs limit" do
    bug = Bug.first

    mklogs = (1..100).map do |i|
      lambda { bug.info "Limit test log #{i}" }
    end
    with_time_passing(*mklogs)

    view_bug(bug.id)
    assert page.has_content?("Limit test log 100"), page.html
    assert page.has_content?("Limit test log 51"), page.html
    refute page.has_content?("Limit test log 50"), page.html

    visit(current_url + '&log_limit=73')

    assert page.has_content?("Limit test log 100"), page.html
    assert page.has_content?("Limit test log 28"), page.html
    refute page.has_content?("Limit test log 27"), page.html
  end

end

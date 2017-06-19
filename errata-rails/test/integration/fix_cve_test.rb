#
# See Bug 881643
# Make sure adding a CVE to a shipped advisory works, even if the advisory
# is not and RHSA.
#
require 'test_helper'

class FixCveTest < ActionDispatch::IntegrationTest
  def setup
    @cve = 'CVE-2012-3524'

    # Set these to unique names (test defaults are normally all "webdev")
    Settings.pub_push_targets = Settings.pub_push_targets.merge(
      :rhn_live => {:target => 'test_rhn_live'},
      :cdn => {:target => 'test_cdn'}
    )
  end

  test "can add cve to shipped live rhba" do
    # Grab a advisories we can test on
    # (Comes from fixture data)
    errata = RHBA.find(18918)

    # Ensure it starts with no cve
    assert errata.content.cve.blank?

    # Go to the fix cve page and set a new a cve
    auth_as secalert_user
    visit "/errata/fixcvenames.cgi?id=#{errata.id}"
    fill_in 'errata_replace_cve', :with => @cve
    click_button 'Replace CVE Names'

    # Should not have experienced any errors
    refute page.has_text?('WARNING: pub tasks have failed'), page.html

    # Did the cve get added? (reload to ensure we get latest data)
    assert_equal @cve, errata.reload.content.cve

    # Was a comment posted about it?  Note that, in this test, the old
    # style pub API was used (no returned task ID), so the comment
    # doesn't mention a pub task.
    comment = errata.reload.comments.last
    assert comment.is_a?(CveChangeComment)
    assert_equal <<-'eos'.strip, comment.text
CVE names have been changed from:

to
CVE-2012-3524
eos
  end

  # Bug 1173489
  test "fix CVE can use new style pub API including pub task link" do
    e = Errata.find(13147)
    new_cve = "#{e.content.cve} CVE-2020-1234"

    pub = pub_mock

    pub.expects(:fix_cves).
      with('test_rhn_live', e.advisory_name, new_cve.split, secalert_user.login_name).
      once.returns(44)

    pub.expects(:fix_cves).
      with('test_cdn', e.advisory_name, new_cve.split, secalert_user.login_name).
      once.returns(55)

    auth_as secalert_user
    visit "/errata/fixcvenames.cgi?id=#{e.id}"
    fill_in 'errata_replace_cve', :with => new_cve

    VCR.use_cassette 'fix_cve_new_pub_api' do
      assert_difference("ActionMailer::Base.deliveries.length", 1) do
        click_button 'Replace CVE Names'
      end
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal 'CVE-CHANGE', mail['X-ErrataTool-Action'].value

    assert_equal new_cve, e.reload.content.cve

    comment = e.reload.comments.last
    assert comment.is_a?(CveChangeComment)
    assert_equal <<-'eos'.strip, comment.text
CVE names have been changed from:
CVE-2012-2328
to
CVE-2012-2328 CVE-2020-1234

Fix CVEs for rhn_live pub task: http://pub.qa.engineering.redhat.com/pub/task/44

Fix CVEs for cdn pub task: http://pub.qa.engineering.redhat.com/pub/task/55
eos
  end

  test "fix CVE can tolerate pub errors" do
    e = Errata.find(13147)
    new_cve = "#{e.content.cve} CVE-2020-1234"

    pub = pub_mock

    pub.expects(:fix_cves).
      with('test_rhn_live', e.advisory_name, new_cve.split, secalert_user.login_name).
      once.returns(44)

    pub.expects(:fix_cves).
      with('test_cdn', e.advisory_name, new_cve.split, secalert_user.login_name).
      once.raises('simulated error')

    auth_as secalert_user
    visit "/errata/fixcvenames.cgi?id=#{e.id}"
    fill_in 'errata_replace_cve', :with => new_cve

    VCR.use_cassette 'fix_cve_pub_errors' do
      click_button 'Replace CVE Names'
    end


    # It should have warned about the fix_cves which couldn't work.
    assert page.has_text?('WARNING: pub tasks have failed'), page.html
    assert page.has_text?('Pub fix_cves call for cdn (test_cdn) failed'), page.html
    assert page.has_text?('simulated error'), page.html

    assert_equal new_cve, e.reload.content.cve

    assert_equal <<-'eos'.strip, e.reload.comments.last.text
CVE names have been changed from:
CVE-2012-2328
to
CVE-2012-2328 CVE-2020-1234

Fix CVEs for rhn_live pub task: http://pub.qa.engineering.redhat.com/pub/task/44
eos
  end

  test "can't add cve to not shipped live rhba" do
    # Grab a advisories we can test on
    # (Comes from fixture data)
    errata = RHBA.rel_prep.last

    # Ensure it starts with no cve
    assert errata.content.cve.blank?

    # Go to the fix cve page and set a new a cve
    # (Page should not allow it)
    auth_as secalert_user
    visit "/errata/fixcvenames.cgi?id=#{errata.id}"
    assert page.has_content? "has not been pushed to RHN Live yet"
    refute page.has_button? 'Replace CVE Names'

    # (Might as well test the before_save callback too..)
    errata.content.cve = @cve
    errata.content.save!
    assert errata.content.cve.blank?
  end

  test 'errors during OVAL part of fix cves are detected' do
    errata = RHBA.find(20466)

    assert errata.content.cve.blank?

    auth_as secalert_user
    visit "/errata/fixcvenames.cgi?id=#{errata.id}"
    fill_in 'errata_replace_cve', :with => @cve

    Push::Oval.expects(:push_oval_to_secalert).once.raises(
      RuntimeError.new('SIMULATED ERROR'))
    click_button 'Replace CVE Names'

    assert find('#flash_error').has_text?(
      "Error occurred updating errata OVAL: SIMULATED ERROR"), page.html
  end

  test 'push xml job enqueued when replacing CVE names' do
    errata = RHSA.shipped_live.last

    auth_as secalert_user
    visit "/errata/fixcvenames.cgi?id=#{errata.id}"
    fill_in 'errata_replace_cve', :with => @cve

    Push::ErrataXmlJob.expects(:enqueue).once.with(errata)
    click_button 'Replace CVE Names'
  end

  test 'errors during push xml are detected' do
    errata = RHSA.shipped_live.last

    auth_as secalert_user
    visit "/errata/fixcvenames.cgi?id=#{errata.id}"
    fill_in 'errata_replace_cve', :with => @cve

    Push::ErrataXmlJob.expects(:enqueue).once.with(errata).raises(
      RuntimeError.new('SIMULATED ERROR'))
    click_button 'Replace CVE Names'

    assert find('#flash_error').has_text?(
      "Error occurred pushing XML to secalert: SIMULATED ERROR"), page.html
  end

  def pub_mock
    # Use a real pub client with a faked XML-RPC proxy
    proxy = mock()
    pub = Push::PubClient.new
    Push::PubClient.stubs(:new => pub)
    pub.instance_variable_set('@errata_proxy', proxy)
    proxy
  end

  test "fix CVE for docker container" do
    e = Errata.find(24604)
    assert e.cve_list.empty?

    new_cve = "CVE-2020-1234"
    expected_cves = e.container_cves + [new_cve]

    pub = pub_mock
    pub.expects(:fix_cves).
      with('test_cdn', e.advisory_name, expected_cves, secalert_user.login_name).
      once.returns(55)

    auth_as secalert_user
    visit "/errata/fixcvenames.cgi?id=#{e.id}"
    fill_in 'errata_replace_cve', :with => new_cve

    VCR.use_cassette 'fix_cve_docker_container_1' do
      click_button 'Replace CVE Names'
    end

    assert e.reload.all_cves.include? new_cve

    new_cve2 = "CVE-2020-5678"
    expected_cves = e.container_cves + [new_cve2]

    pub.expects(:fix_cves).
      with('test_cdn', e.advisory_name, expected_cves, secalert_user.login_name).
      once.returns(55)

    visit "/errata/fixcvenames.cgi?id=#{e.id}"
    fill_in 'errata_replace_cve', :with => new_cve2

    VCR.use_cassette 'fix_cve_docker_container_2' do
      click_button 'Replace CVE Names'
    end

    refute e.reload.all_cves.include? new_cve
    assert e.reload.all_cves.include? new_cve2
  end

end

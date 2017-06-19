require 'test_helper'

class NotificationOnReleaseChangeTest < ActionDispatch::IntegrationTest
  #
  # Mark is an engineer at Red Hat, but is often interrupted in his work
  # by his manager. He wants a status update on what Mark is working on
  # every 5 minutes. This leads to advisories, which he sometimes files
  # under the wrong release. He needs to be able to amend that:
  #
  # https://bugzilla.redhat.com/show_bug.cgi?id=978077
  #
  def setup
    #
    # The flash message is only shown, if the rule set changes. There is
    # only one default rule set available by the fixture data. We create
    # a new one, attach it to a release and append it to the list of
    # active releases of the advisories product. That way we can check
    # two possible scenarios:
    #
    #   * the release has changed, but not the rule set and therefore no
    #     flash message is shown.
    #
    #   * the release has changed with a new rule set and therefore the
    #     flash message notifies the user that the workflow will be reset.
    #
    @errata = Errata.find(11152)
    new_rule_set = StateMachineRuleSet.default_rule_set.create_duplicate_rule_set!(
      'R2', 'Yet another rule set')
    release = Async.create!(:name => "NewStateMachineTest",
                            :description => "New State Machine Test",
                            :product => @errata.product,
                            :state_machine_rule_set => new_rule_set)
    @ruleset_changed_release = release.name


    assert_nil @errata.custom_state_machine_rule_set
    assert_not_nil release.state_machine_rule_set
    assert_not_equal release, @errata.release
    assert_not_equal release.state_machine_rule_set, @errata.state_machine_rule_set

    @errata.product.active_releases.push(release)
    @expected_alert = "workflow rule set will be changed"
  end

  test "flash message after release and ruleset change" do
    auth_as devel_user

    #
    # Mark changes to a release, which also changes the rule set. Now
    # make him aware of that with a flash message.
    #
    visit "/errata/edit/#{@errata.id}"
    select @ruleset_changed_release, :from => 'release_id'
    click_button('Preview')
    assert find('div#flash_alert').has_content?(@expected_alert), page.html
  end

  test "no flash message when ruleset stays the same." do
    auth_as devel_user
    visit "/errata/edit/#{@errata.id}"
    assert page.has_content?('Advisory Summary')
    assert find('div#flash_alert', visible: false).has_no_content?(@expected_alert)

    #
    # Mark selects a different release for this advisory. This one will
    # not change the rule set and we don't expect a flash message.
    #
    select 'FAST5.7', :from => 'release_id'
    click_button('Preview')
    assert find('div#flash_alert', visible: false).has_no_content?(@expected_alert)
  end
end

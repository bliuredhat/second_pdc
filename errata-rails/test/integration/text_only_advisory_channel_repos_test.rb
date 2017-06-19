require 'test_helper'

class TextOnlyAdvisoryChannelReposTest < ActionDispatch::IntegrationTest

  def setup
    rhba_async.update_attribute(:text_only, 1)
  end

  test "can set channels and cdn repos successfully" do
    repos =  %w{rhel-6-server-rpms__6Server__x86_64 rhel-6-server-rpms__6Server__ppc64}
    channels = %w{rhel-x86_64-client-fastrack-6 rhel-i386-server-fastrack-6}
    auth_as devel_user
    visit "/errata/text_only_channels/#{rhba_async.id}"

    # No Docker, Source or DebugInfo repos should be listed
    refute has_text? '(Docker)'
    refute has_text? '(Source)'
    refute has_text? '(DebugInfo)'

    # but Binary repos should be listed
    assert has_text? '(Binary)'

    (repos + channels).each { |name| check name}

    click_on 'Update'
    assert has_text?('Channels/Repositories updated')

    first(:css, '.workflow-step-name-set_text_only_rhn_channels').click_on 'Set'

    (repos + channels).each do |name|
      assert has_checked_field? name
    end
  end

end

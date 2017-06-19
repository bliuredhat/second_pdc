require 'test_helper'

class ReleaseAdminTest < ActionDispatch::IntegrationTest

  test 'can select workflow rule set' do
    auth_as admin_user

    release = Release.find(21)
    assert_nil release.state_machine_rule_set

    visit "/release/edit/#{release.id}"

    assert_equal '(unset)', selected_rule_set.text

    select 'CDN Push Only', :from => 'Workflow Rule Set'
    click_on 'Edit'

    assert_equal 'CDN Push Only', release.reload.state_machine_rule_set.name
  end

  test 'can unset workflow rule set' do
    auth_as admin_user

    release = Release.find(468)
    assert_not_nil release.state_machine_rule_set

    visit "/release/edit/#{release.id}"

    assert_equal release.state_machine_rule_set.name, selected_rule_set.text

    select '(unset)', :from => 'Workflow Rule Set'
    click_on 'Edit'

    assert_nil release.reload.state_machine_rule_set
  end

  test 'associate a pdc release to a release' do
    auth_as admin_user

    release = Release.find_by_name('ReleaseTestPdcRelease')

    VCR.use_cassette 'release_admin_release_info' do
      visit "/release/edit/#{release.id}"
    end

    assert_false page.has_selector? "#release_pdc_releases_[disabled]"
    find(:css, "#release_pdc_releases_[value='ceph-1.3@rhel-7']").set(true)
    click_on 'Edit'
    assert_equal release.pdc_releases.first.pdc_id, 'ceph-1.3@rhel-7'
  end

  test 'remove associated pdc release from a release' do
    auth_as admin_user

    release = Release.find_by_name('ReleaseTestPdcRelease')

    VCR.use_cassette 'release_admin_release_info' do
      visit "/release/edit/#{release.id}"
    end

    find(:css, "#release_pdc_releases_[value='ceph-1.3@rhel-7']").set(true)
    click_on 'Edit'

    VCR.use_cassette 'release_admin_release_info' do
      visit "/release/edit/#{release.id}"
    end

    find(:css, "#release_pdc_releases_[value='ceph-1.3@rhel-7']").set(false)
    click_on 'Edit'
    assert_true release.pdc_releases.empty?
  end

  test 'if a release has a advisory can not change its product' do
    auth_as admin_user

    release = Release.find_by_name('ReleaseTestPdcRelease1')
    VCR.use_cassette 'release_admin_release_info' do
      visit "/release/edit/#{release.id}"
    end
    assert page.has_selector? '#release_product_id[disabled]'
  end

  test 'if a release has a advisory can not remove related pdc release' do
    auth_as admin_user

    release = Release.find_by_name('ReleaseTestPdcRelease1')
    VCR.use_cassette 'release_admin_release_info' do
      visit "/release/edit/#{release.id}"
    end
    assert page.has_selector? "#release_pdc_releases_[disabled]"
  end

  test 'if a release has a advisory can edit other parts' do
    auth_as admin_user

    release = Release.find_by_name('ReleaseTestPdcRelease1')
    VCR.use_cassette 'release_admin_release_info' do
      visit "/release/edit/#{release.id}"
    end
    assert_equal '(unset)', selected_rule_set.text
    select 'CDN Push Only', :from => 'Workflow Rule Set'
    click_on 'Edit'
    assert_equal 'CDN Push Only', release.reload.state_machine_rule_set.name
  end

  def selected_rule_set
    find(:xpath, '//label[contains(text(),"Workflow Rule Set")]/following-sibling::select/option[@selected]')
  end
end

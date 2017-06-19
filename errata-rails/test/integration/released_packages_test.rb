require 'test_helper'

class ReleasedPackagesListTest < ActionDispatch::IntegrationTest

  test 'released package listing contains ruby with user info' do
    auth_as releng_user
    visit '/release_engineering/released_packages/149'
    select 'RHEL-6'

    ruby_row = find(:xpath, '//*[@id="brew_build_421698"]')
    assert ruby_row.has_content? 'ruby-1.8.7.374-4.el6_6'
    assert ruby_row.has_content? 'Devel User <errata-test@redhat.com>'
    assert ruby_row.has_content? 'Ruby 1.8.7 released into RHEL-6'
    assert ruby_row.has_content? '2015-08-13 13:02:24 UTC'
  end

  test 'old entries: released package with associated errata shows details' do
    auth_as releng_user
    visit '/release_engineering/released_packages/149'
    select 'RHEL-6'

    krb5_row = find(:xpath, '//*[@id="brew_build_162233"]')
    assert krb5_row.has_content? 'krb5-1.8.2-3.el6_0.7'
    assert krb5_row.has_content? 'Added automatically'
    assert krb5_row.has_content? 'Generated for advisory RHSA-2011:0447'
    assert krb5_row.has_content? '--'
  end

  test 'old entries: released package without no details shows Unknown' do
    auth_as releng_user
    visit '/release_engineering/released_packages/149'
    select 'RHEL-6'

    krb5_row = find(:xpath, '//*[@id="brew_build_300001"]')
    assert krb5_row.has_content? 'sblim-cim-client2-2.1.3-1.el6'
    assert krb5_row.has_content? 'Unknown'
    assert krb5_row.has_content? '--'
  end
end

# -*- coding: utf-8 -*-
require 'test_helper'

class ErrataDetailsTest < ActionDispatch::IntegrationTest
  test 'fields display expected values' do
    auth_as devel_user
    visit '/errata/details/11123'

    [
      ['Product', 'Red Hat Enterprise Linux Extras (RHEL-EXTRAS)'],
      ['Release', 'RHEL-6.1.0'],
      ['Package Owner', 'Marek Kašík (mkasik)'],
      # not sure why month is in caps some places but not others ...
      ['Creation Date', '2011-APR-13'],
      ['Release Date', '2011-May-31 (default)'],
      # bug 1168671
      ['Cc List', 'qa-errata-list, omoris'],
      ['Bug Statuses', 'VERIFIED: 1 (100%)'],
      ['Reboot Suggested', 'No'],
    ].each { |field, expected| check_field_contents field, expected }
  end

  test 'displays reboot suggested when appropriate' do
    auth_as devel_user
    visit '/errata/details/19828'

    elem = all(:xpath, field_value_xpath('Reboot Suggested')).select(&:visible?)
    assert_equal 1, elem.length, 'Could not find exactly one "Reboot Suggested"'
    elem = elem.first

    actual = elem.text
    assert_equal 'Yes', actual

    # Basic verification of the popover
    popover = elem.find(:css, 'a.popover-test')
    content = popover['data-content']

    assert_equal(
      "Ships kernel to RHEL-6.6.Z<br>Ships kernel-firmware to RHEL-6.6.Z",
      content)
  end

  test 'shows container CVEs' do
    auth_as devel_user
    visit '/errata/details/24604'
    check_field_contents 'Container CVEs', 'CVE-2016-3134, CVE-2016-4997, CVE-2016-4998'
  end

  def field_value_xpath(name)
    "//td[text()='#{name}' and @class='small_label']/following::td[1]"
  end

  def check_field_contents(field, expected)
    elem = all(:xpath, field_value_xpath(field)).select(&:visible?)
    assert_equal 1, elem.length, "could not find exactly one visible field named #{field}"
    actual = elem.first.text
    assert_equal expected, actual, "wrong value displayed for #{field}"
  end
end

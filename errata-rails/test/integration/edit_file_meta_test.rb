require 'test_helper'

class EditFileMetaTest < ActionDispatch::IntegrationTest

  # TODO: using the UI to edit file meta is entirely reliant on
  # javascript, making most cases untestable! If our test
  # infrastructure ever supports testing with javascript, please
  # consider adding more tests.

  TEST_META = [
    # Note these should match the fixture rank order
    ['win/usbclerk-x86-0.3.3.msi',             'USB Clerk installer (32-bit)'],
    ['win/usbclerk-x64-0.3.3.msi',             'USB Clerk installer (64-bit)'],
    ['win/virt-viewer-x86-0.5.6.msi',          'Virt Viewer installer (32-bit)'],
    ['win/virt-viewer-x64-0.5.6.msi',          'Virt Viewer installer (64-bit)'],
    ['win/spice-client-msi-3.4-4-sources.zip', 'Spice client installer sources'],
    ['win/spice-client-msi-3.4-4-spec.zip',    'Spice client installer build sources'],
  ]

  test 'can navigate using Files tab when appropriate' do
    e = Errata.find(16409)

    auth_as devel_user
    visit "/advisory/#{e.id}"

    click_on('Files')
    assert page.has_text?('Manage file attributes')

    # and can go back
    click_on('Summary')
    assert page.has_text?('Approval Progress')
  end

  test 'no Files tab when RPM files only' do
    e = Errata.find(11142)
    assert e.brew_rpms.any?
    assert e.brew_files.nonrpm.none?

    auth_as devel_user
    visit "/advisory/#{e.id}"

    assert_raises(Capybara::ElementNotFound) { click_on('Files') }
  end

  test 'no Files tab when docker image files only' do
    e = Errata.find(21100)
    assert e.has_docker?
    refute e.has_brew_files_requiring_meta?

    auth_as devel_user
    visit "/advisory/#{e.id}"

    assert_raises(Capybara::ElementNotFound) { click_on('Files') }
  end

  test 'file meta displayed OK for advisory with locked filelist' do
    e = Errata.find(16409)

    auth_as devel_user
    visit "/brew/edit_file_meta/#{e.id}"

    assert page.has_text?('The file list is currently locked'), page.html

    TEST_META.each do |filename,title|
      within(:xpath, xpath_for_file_tr(filename)) do
        assert has_text?(title), "Missing #{title}!\n#{html}"
        refute has_text?('Edit'), "Edit button incorrectly displayed!\n#{html}"
      end
    end
  end

  test 'file meta displayed OK for advisory with unlocked filelist' do
    e = Errata.find(16409)

    e.change_state!('NEW_FILES', devel_user)

    auth_as devel_user
    visit "/brew/edit_file_meta/#{e.id}"

    refute page.has_text?('The file list is currently locked'), page.html

    TEST_META.each do |filename,title|
      within(:xpath, xpath_for_file_tr(filename)) do
        assert has_text?(title), "Missing #{title}!\n#{html}"
        assert has_text?('Edit'), "Missing edit button for #{filename}!\n#{html}"
      end
    end
  end

  test 'file meta displayed OK when records do not yet exist' do
    e = Errata.find(16409)

    e.change_state!('NEW_FILES', devel_user)
    BrewFileMeta.where(:errata_id => e).delete_all

    auth_as devel_user

    # merely viewing the page should not persist any BrewFileMeta
    assert_no_difference('BrewFileMeta.count') do
      visit "/brew/edit_file_meta/#{e.id}"

      TEST_META.each do |filename,_|
        within(:xpath, xpath_for_file_tr(filename)) do
          assert has_text?('(unset)'), "Missing (unset) for #{filename}!\n#{html}"
          assert has_text?('Edit'), "Missing edit button for #{filename}!\n#{html}"
        end
      end
    end
  end

  test 'file meta displayed in rank order' do
    e = Errata.find(16409)

    auth_as devel_user
    visit "/brew/edit_file_meta/#{e.id}"

    all_texts = all(:css, 'tr').map(&:text)
    puts all_texts.inspect

    text_indices = TEST_META.map(&:second).map do |expected_text|
      all_texts.find_index{|actual_text| actual_text.include?(expected_text)}
    end

    # ensure every text appeared
    assert_equal TEST_META.length, text_indices.length

    # text_indices is now the order in which the texts in TEST_META
    # really appeared on the page.  It's expected to be the same as
    # they've been declared in TEST_META.
    assert_equal text_indices.sort, text_indices
  end

  test 'advisory with all rank initialized hides rank form by default' do
    e = Errata.find(16409)

    e.change_state!('NEW_FILES', devel_user)

    auth_as devel_user
    visit "/brew/edit_file_meta/#{e.id}"

    refute has_selector?(:button, 'Save', :visible => true), html
  end

  test 'advisory with some rank uninitialized shows rank form by default' do
    e = Errata.find(16397)

    auth_as devel_user
    visit "/brew/edit_file_meta/#{e.id}"

    assert has_selector?(:button, 'Save', :visible => true), html
  end

  test 'file meta rows are not sortable for advisory with locked filelist' do
    e = Errata.find(16409)

    auth_as devel_user
    visit "/brew/edit_file_meta/#{e.id}"

    # A weak test, but better than nothing.  The absence of
    # .et-sortable implies jQuery UI sortable will not be activated.
    refute page.has_selector?(:css, '.et-sortable', :visible => true), page.html
  end

  test 'file meta rows are sortable for advisory with unlocked filelist' do
    e = Errata.find(16397)

    auth_as devel_user
    visit "/brew/edit_file_meta/#{e.id}"

    assert page.has_selector?(:css, '.et-sortable', :visible => true), page.html
  end

  def xpath_for_file_tr(file)
    "//tr[.//*[contains(text(), '#{file}')]]"
  end
end

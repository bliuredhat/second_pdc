require 'test_helper'

class CdnRepoPackageTest < ActionDispatch::IntegrationTest

  test "cdn repo package tags" do
    auth_as admin_user

    cdn_repo = CdnRepo.find(3001)
    package = cdn_repo.packages.sort_by(&:name).first
    mapping = cdn_repo.cdn_repo_packages.where(:package_id => package.id).first
    tag_count = mapping.cdn_repo_package_tags.count
    path = variant_cdn_repo_path(cdn_repo.variant, cdn_repo)

    visit path

    # Click on 'Packages' tag
    within('#object_tab') { click_link 'Packages' }

    # Click on 'Tags' button for first package
    first(:link, 'Tags').click

    # Now the package_tags.html.erb template should be rendered
    assert page.has_content? "Tags for '#{package.name}'"
    assert_equal tag_count, all('.btn-delete').count
    assert find('.btn-add')

    # Create a new tag
    click_on 'Add'
    fill_in 'tag_template', :with => '__test_tag__', :visible => false
    within('.exclusion_form', visible: false) { click_on 'Create', visible: false }

    # Should now be an extra tag (and delete button) shown
    assert_equal tag_count+1, all('.btn-delete').count

    # Click on 'Delete' button for first tag
    first(:link, 'Delete').click

    # Should now be back to original tag count
    assert_equal tag_count, all('.btn-delete').count

    # Go back, should return to initial path
    click_on 'Back'
    assert page.has_content? "The following packages are associated"
    assert_equal path, page.current_path
  end

end

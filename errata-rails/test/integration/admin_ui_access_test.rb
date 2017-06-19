require 'test_helper'

class AdminUiAccessTest < ActionDispatch::IntegrationTest

  def has_create_sidebar_links?
    has_css?('h3', text: 'Create') || has_css?('.icon-plus')
  end

  def has_edit_button?
    has_css?('.icon-pencil')
  end

  def has_action_button?
    has_css?('button.dropdown-toggle', text: 'Action')
  end

  def has_checkbox?
    has_css?('input[type="checkbox"]')
  end

  def check_admin_only(test)
    auth_as admin_user
    test[:setup].call
    test[:checks].each { |msg, check| assert check.call, msg }

    auth_as devel_user
    test[:setup].call
    test[:checks].each { |msg, check| refute check.call, msg }
  end

  def check_edit_links(url)
    check_admin_only({
      setup: -> {
        visit url
      },
      checks: {
        'Create links' => ->{ has_create_sidebar_links? },
        'Edit button'  => ->{ has_edit_button? }
      }
    })
  end

  test "product edit button" do
    product = Product.find(16)
    check_admin_only({
      setup: -> {
        visit "/products/#{product.id}"
      },
      checks: {
        'Edit button'  => ->{ has_edit_button? }
      }
    })
  end

  test "product_versions edit links" do
    pv = ProductVersion.find(419)
    check_edit_links "/product_versions/#{pv.id}"
  end

  test "variant edit links" do
    variant = Variant.find(1037)
    check_edit_links "/variants/#{variant.id}"
  end

  test "cdn_repos edit links" do
    pv = ProductVersion.find(419)
    cdn_repo = CdnRepo.find(2178)
    check_edit_links "/product_versions/#{pv.id}/cdn_repos/#{cdn_repo.id}"
  end

  test "channels edit links" do
    pv = ProductVersion.find(419)
    channel = Channel.find(1348)
    check_edit_links "/product_versions/#{pv.id}/channels/#{channel.id}"
  end

  test "variants" do
    variant = Variant.find(594)
    assert variant.package_restrictions.any?
    assert variant.cdn_repos.enabled.any?
    assert variant.channels.any?

    check_admin_only({
      setup: -> {
        visit "/variants/#{variant.id}"
      },
      checks: {
        # Package restrictions
        'Action header' => ->{ has_css?('th', text: 'Action') },
        'Edit link'     => ->{ has_css?('td a', text: 'Edit') },
        'Delete link'   => ->{ has_css?('td a', text: 'Delete') },
        'Add button'    => ->{ has_css?('a.btn', text: 'Add') },

        # Attached CDN repos / RHN channels
        'Action button' => ->{ has_action_button? },
        'Has checkbox'  => ->{ has_checkbox? }
      }
    })
  end

  test "variant cdn repos" do
    variant = Variant.find(594)
    assert variant.cdn_repos.any?

    check_admin_only({
      setup: -> {
        visit "/variants/#{variant.id}/cdn_repos"
      },
      checks: {
        'Action button' => ->{ has_action_button? },
        'Has checkbox'  => ->{ has_checkbox? },
        'Detach button' => ->{ has_button? 'Detach selected' }
      }
    })
  end

end

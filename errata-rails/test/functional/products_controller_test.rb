require 'test_helper'

class ProductsControllerTest < ActionController::TestCase
  fixtures :product_versions

  def setup
    auth_as admin_user
  end

  def test_index
    get :index
    assert_response :success
    assert_template 'index'
  end

  def test_new
    get :new
    assert_response :success
  end

  def test_rpm_prefixes
    product = Product.find(82)
    assert product.brew_rpm_name_prefixes.empty?

    product.add_brew_rpm_name_prefix('blah123')
    get :rpm_prefixes
    assert_response :success
    assert_select 'h1', 'Brew RPM Name Prefixes'
    assert_select 'td', 'blah123'
  end

end

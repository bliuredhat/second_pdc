require 'test_helper'

class ProductListingsDebugTest < ActionDispatch::IntegrationTest
  # TODO: javascript features of this page are untested!

  def product_listings_debug_test(opts)
    Brew.stubs(:get_connection => DummyBrew.new)

    auth_as releng_user

    visit '/release_engineering/product_listings'

    # initially no debug stuff visible
    refute prefetch_debug_elem
    refute debug_elem

    select opts[:pv], :from => 'rp_pv_or_pr_id'
    fill_in 'rp_nvr', :with => opts[:nvr]

    debug_action = self.method(opts.fetch(:debug, true) ? :check : :uncheck)
    debug_action.call('Show additional debug info')

    ActiveSupport::TestCase.with_replaced_method(Benchmark, :realtime,
      lambda{|&block| block.call(); 1.0}
    ) do
      click_on 'Get Listing'
    end

    refute has_text?('An error has occurred'), page.html

    text = nice_text(prefetch_debug_elem) + "\n" + nice_text(debug_elem)

    assert_testdata_equal "product_listings_debug/#{opts[:name]}.txt", text
  end

  def product_listings_connectivity_checker(desc)
    url = '/release_engineering/product_listings?rp%5Bnvr%5D=libvirt-0.10.2-46.el6_6.6&rp%5Bpv_or_pr_id%5D=384'
    err_msg = desc.upcase + ' ERROR'
    visit url
    # Ensure that it's a proper Product Listings Page, but contains
    # a non-traceback message describing the connectivity issue.
    assert page.has_text?('Product Listings for RHEL-6.6.z Build libvirt-0.10.2-46.el6_6.6'), "Product listings message should be shown even with #{desc} problem"
    assert page.has_text?(err_msg), "error for #{desc} should be shown"
  end

  test 'shows and survives connectivity exceptions' do
    testables = {
      'connection' => Errno::ECONNREFUSED,
      'host down' => Errno::EHOSTDOWN,
      'host unreachable' => Errno::EHOSTUNREACH
    }
    auth_as releng_user
    Brew.stubs(:get_connection => DummyBrew.new)
    testables.each_pair do |description, error_type|
      DummyBrew.any_instance.stubs(:getProductListings).raises(error_type.new("simulated #{description} error".upcase))
      product_listings_connectivity_checker(description)
    end
  end

  test 'debug split product listings' do
    product_listings_debug_test :pv => 'RHEL-6.6.z',
      :nvr => 'openscap-1.0.10-2.el6',
      :name => 'typical-split-listings'
  end

  test 'debug unified product listings' do
    product_listings_debug_test :pv => 'RHEL-7',
      :nvr => 'sos-3.0-23.el7_0.11',
      :name => 'typical-unified-listings'
  end

  test 'includes multi-product RHN listings when appropriate' do
    product_listings_debug_test :pv => 'RHEL-6',
      :nvr => 'jasper-1.900.1-16.el6_6.2',
      :name => 'multi-product-listings-rhn'
  end

  test 'includes multi-product CDN listings when appropriate' do
    product_listings_debug_test :pv => 'RHEL-6',
      :nvr => 'iwl100-firmware-39.31.5.1-1.el6',
      :name => 'multi-product-listings-cdn'
  end

  test 'warning when variants are configured badly' do
    # this is just some product version in the fixtures without its
    # variants
    product_listings_debug_test :pv => 'RHEL-4.6.Z-RHCS',
      :nvr => 'sos-3.0-23.el7_0.11',
      :name => 'bad-variants'
  end

  test 'shows the call which resulted in an error' do
    DummyBrew.any_instance.stubs(:getProductListings).
      raises(XMLRPC::FaultException.new(1234, 'SIMULATED ERROR'))
    product_listings_debug_test :pv => 'RHEL-6.6.z',
      :nvr => 'openscap-1.0.10-2.el6',
      :name => 'brew-error'
  end

  test 'no debug text if unchecked' do
    product_listings_debug_test :pv => 'RHEL-6.6.z',
      :nvr => 'openscap-1.0.10-2.el6',
      :name => 'nodebug-listing',
      :debug => false
  end

  test 'debug with manifest api enabled' do
    Settings.manifest_api_enabled = true
    Settings.manifest_api_url = 'http://example.com/'

    stub_request(
      :get,
      'http://example.com/composedb/get-product-listings/RHEL-7/sos-3.0-23.el7_0.11'
    ).to_return(:body => '{"some":"data"}')

    product_listings_debug_test :pv => 'RHEL-7',
      :nvr => 'sos-3.0-23.el7_0.11',
      :name => 'with-manifest-api'
  end

  def prefetch_debug_elem
    first('#product-listings-prefetch-debug', :visible => true)
  end

  def debug_elem
    first('#product-listings-debug', :visible => true)
  end

  # Capybara's whitespace normalization is broken (it strips even
  # significant whitespace, such as <br> and whitespace within <pre>).
  #
  # This method gets the text from the native element instead and does
  # some basic cleanup only.
  #
  # Also, it returns an empty string if the element is nil.
  def nice_text(elem)
    return '' if elem.nil?
    elem.native.text.strip_heredoc.strip.
      gsub(/\n\s*\n(\s*\n)+/, "\n\n").
      gsub(/[ \t]+\n/, "\n") + "\n"
  end

  class DummyBrew
    def getProductListings(*args)
      {'dummy_variant' => {'called_with' => args}}
    end
  end
end

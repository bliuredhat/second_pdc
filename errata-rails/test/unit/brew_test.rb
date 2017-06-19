require 'test_helper'
require 'brew'

class BrewTest < ActiveSupport::TestCase

  def setup
    # Found this mapping since, it's release is connected to a
    # QuarterlyUpdate which has brew tags set
    @mapping = ErrataBrewMapping.find(21198)
    @brew_build, @errata = @mapping.brew_build, @mapping.errata
  end

  test "old builds by package" do
    expected = HashSet.new
    expected[@brew_build.package] = Set.new << @mapping
    brew = Brew.new
    brew.expects(:old_maps_by_package).returns(expected)

    maps = brew.old_builds_by_package(@errata, @errata.available_product_versions.first)
    assert_equal expected.count, maps.count
    assert_equal expected.keys, maps.keys
    assert_equal expected.values.first.map(&:brew_build), maps.values
  end

  test "list tags" do
    proxy = mock('Proxy')
    proxy.expects(:listTags).returns([{'name' => :RHEL}])
    server = mock('Server')
    server.expects(:proxy).returns(proxy)

    XMLRPC::Client.expects(:new2).returns(server)

    brew = Brew.get_connection
    assert_equal [:RHEL], brew.list_tags(BrewBuild.last)
  end

  test "list tags with bad response" do
    proxy = mock('Proxy')
    proxy.expects(:listTags).returns(some_bananas = {'bananas'=>42})
    server = mock('Server')
    server.expects(:proxy).returns(proxy)

    XMLRPC::Client.expects(:new2).returns(server)
    brew = Brew.get_connection
    brew_build = BrewBuild.last
    e = assert_raise(RuntimeError) { brew.list_tags(brew_build) }
    assert_equal "Invalid tag data for #{brew_build.nvr} from brew: #{some_bananas.inspect}", e.message
  end

  test "get valid tags" do
    tags = Brew.new.get_valid_tags(@errata, @errata.available_product_versions.first)
    assert tags.any?
    assert_equal @errata.release.brew_tags.collect { |t| t.name }, tags
  end

  test "get valid tags does not alter type of brew tags" do
    pv = @errata.product_versions.first
    @errata.release.stubs(:brew_tags).returns([])
    Brew.new.get_valid_tags(@errata, pv)
    assert_instance_of BrewTag, pv.brew_tags.first
  end

  test "build is properly tagged error case" do
    brew = Brew.get_connection
    brew.expects(:list_tags).with(instance_of(BrewBuild)).returns(['rhel-7.0-beta-set', 'rhel-7.0'])
    brew.expects(:get_valid_tags).with(kind_of(Errata), instance_of(ProductVersion)).returns([])

    refute brew.build_is_properly_tagged?(@errata, ProductVersion.last, BrewBuild.last)
    assert_match %r{not have any of the valid tags}, brew.errors.values.join
  end

  test "build is properly tagged" do
    brew = Brew.get_connection
    brew.expects(:list_tags).with(instance_of(BrewBuild)).returns(
      @errata.release.brew_tags.map(&:name).take(2)
    )
    brew.expects(:get_valid_tags).with(kind_of(Errata), instance_of(ProductVersion)).returns(
      @errata.release.brew_tags.map(&:name).first)

    assert brew.build_is_properly_tagged?(@errata, ProductVersion.last, BrewBuild.last)
    assert brew.errors.empty?
  end

  test "delegates unimplemented methods to XMLRPC" do
    proxy_method = :some_weird_method
    proxy = mock('xmlrpc proxy')
    proxy.expects(proxy_method)

    brew = Brew.get_connection
    #
    # Usually it is possible to simply setup expectations or stubs
    # before we instantiate. But this time this didn't work. So here I
    # use this little hack to get my mock proxy called.
    #
    brew.instance_variable_set(:@proxy, proxy)

    assert_nothing_raised XMLRPC::FaultException do
      brew.send(proxy_method)
    end
  end

  test "discard old package silently ignores no old packages" do
    brew = Brew.get_connection
    brew.expects(:old_maps_by_package).with(kind_of(Errata), instance_of(ProductVersion)).returns({})
    assert_no_difference('ErrataBrewMapping.current.count') do
      brew.discard_old_package(@errata, @mapping.product_version, @brew_build.package)
    end
  end

  test "discard an old package" do
    brew = Brew.get_connection
    assert_difference('ErrataBrewMapping.current.count', -1) do
      brew.discard_old_package(@errata, @mapping.product_version, @brew_build.package)
    end
  end

  test 'discard an old package having multiple brew archive types' do
    brew = Brew.get_connection
    # This advisory has 3 build_mappings with different brew archive types
    # from the same build
    errata = Errata.find(16409)
    mappings = errata.build_mappings
    assert_equal 1, mappings.map(&:brew_build_id).uniq.count
    # multiple mappings with the same build
    assert_equal 3, mappings.map(&:brew_archive_type_id).count

    product_version = mappings.first.product_version
    brew_build = mappings.first.brew_build
    assert_difference('ErrataBrewMapping.current.count', -3) do
      brew.discard_old_package(errata, product_version, brew_build.package)
    end
  end

  test "Get product listing should return valid listing" do
    # Found this mapping since, it's release is connected to a
    # QuarterlyUpdate which has brew tags set
    mapping = ErrataBrewMapping.find(21198)
    pv = mapping.errata.product_versions.last
    build = mapping.brew_build

    assert_nothing_raised do
      assert ProductListing.find_or_fetch(pv, build).present?, "Non-empty product listing is expected."
      assert build.has_valid_listing?(pv), "Product Listing is expected to be valid."
      assert_nil build.listing_error(pv), "No error message is expected."
    end
  end

  test "Get product listing should raise error" do
    build = BrewBuild.find_by_nvr("rsh-0.17-76.aa7a_1.1")
    pv = ProductVersion.find_by_name("RHELSA-7.1.Z")
    options = {:use_cache => false}
    exception_message = 'Something Wrong'
    xmlrpc_error = XMLRPC::FaultException.new(1, exception_message)
    Brew.any_instance.stubs(:getProductListings).raises(xmlrpc_error)

    error = assert_raises(XMLRPC::FaultException) do
      ProductListing.find_or_fetch(pv, build, options)
    end
    assert_equal xmlrpc_error, error

    # Try to retrieve the error message
    assert_match exception_message, build.listing_error(pv, options)
  end

  # Bug: 1053533
  test "Get product listing should tolerate timeout error" do
    build = BrewBuild.find_by_nvr("rsh-0.17-76.aa7a_1.1")
    pv = ProductVersion.find_by_name("RHELSA-7.1.Z")
    options = {:use_cache => false}
    Brew.any_instance.stubs(:getProductListings).raises(Timeout::Error.new('timeout'))

    assert_nothing_raised do
      assert_equal({}, ProductListing.find_or_fetch(pv, build, options), "Empty product listing is expected for timeout error.")
      refute build.has_valid_listing?(pv, options), "Product Listing is expected to be invalid."
      assert_nil build.listing_error(pv), "No error message is expected."
    end
  end

  test "Non rpm brew builds can have empty product listing" do
    build = BrewBuild.find_by_nvr("rhel-server-x86_64-ec2-starter-6.5-8")
    pv = ProductVersion.find_by_name("RHEL-6")
    ProductListing.expects(:find_or_fetch).once.returns({})

    assert build.has_valid_listing?(pv), "Product Listing is expected to be valid."
  end
end

require 'test_helper'

class ProductVersionsControllerTest < ActionController::TestCase

  test "add brew tag" do
    auth_as admin_user
    pversion = ProductVersion.last
    pversion.brew_tags << BrewTag.first
    pversion.save!

    assert_no_difference('BrewTag.count') {
      [:html, :js].each do |format|
        post :add_tag, :id => pversion, :tag => {:name=>""}, :format => format
        assert_response :success

        post :add_tag, :id => pversion, :tag => {:name => BrewTag.first.name}, :format => format
        assert_response :success
      end
    }

    assert_difference('BrewTag.count') {
      [:html, :js].each do |format|
        post :add_tag, :id=>pversion, :tag=>{:name=>"testtag"}, :format => format
        assert_response :success
      end
    }
  end

  test "can add and remove push targets" do
    auth_as admin_user
    product_version_id = 272
    product_version = ProductVersion.find(product_version_id)
    product = product_version.product

    # Can set push targets
    get :update, :id => product_version_id.to_s, :product_version => { :push_targets => product.push_targets.map(&:id) }
    assert_redirected_to :action => :show, :id => product_version_id
    assert_equal product.push_targets.map(&:id).sort, ProductVersion.find(product_version_id).active_push_targets.map(&:push_target_id).sort

    # Can also clear them (didn't work prior to bz 1017142)
    get :update, :id => product_version_id.to_s, :product_version => {}
    assert_redirected_to :action => :show, :id => product_version_id
    assert ProductVersion.find(product_version_id).active_push_targets.empty?
  end

  test "forbid_ftp and supports_cdn set correctly for new product version" do
    [
      [ %w'rhn_live rhn_stage ftp', false, false ],
      [ %w'rhn_live rhn_stage',     true,  false ],
      [ %w'cdn',                    true,  true  ]
    ].each_with_index do |(push_targets, expected_forbid_ftp, expected_supports_cdn), i|
      auth_as admin_user

      create_params = {
        "product_id"=>Product.find_by_short_name('RHEL').id.to_s,
        "product_version"=>{
          "allow_rhn_debuginfo"=>"0",
          "rhel_release_id"=>"1",
          "is_server_only"=>"0",
          "enabled"=>"1",
          "name"=>"foo#{i}",
          "description"=>"bar#{i}",
          "default_brew_tag"=>"",
          "push_targets"=>PushTarget.where(:name=>push_targets).map(&:id).map(&:to_s),
          "is_rhel_addon"=>"0",
          "is_oval_product"=>"0",
          "sig_key_id"=>"1"}
      }

      #pp create_params
      post :create, create_params
      assert_response :redirect

      product_version = ProductVersion.last
      assert_equal "foo#{i}", product_version.name
      assert_equal "bar#{i}", product_version.description
      assert_equal push_targets.sort, product_version.push_targets.map(&:name).sort

      # Now the main event... (see Bug 1008380)
      assert_equal expected_forbid_ftp, product_version.forbid_ftp, "expected #{expected_forbid_ftp} forbid_ftp for #{push_targets.join(', ')}"
      assert_equal expected_supports_cdn, product_version.supports_cdn, "expected #{expected_supports_cdn} supports_cdn for for #{push_targets.join(', ')}"
    end
  end

  test "shows variants linked by channels" do
    auth_as admin_user

    # eliminate all CDN repo links to test RHN-only links
    [180,196].each do |id|
      ProductVersion.find(id).cdn_repo_links.destroy_all
    end

    ids = {
      180 => {
        :link_variants => {
          '6Server-LoadBalancer-6.1.z' => ['6Server-LoadBalancer-6.1.EUS'],
          '6Server-ScalableFileSystem-6.1.z' => ['6Server-ScalableFileSystem-6.1.EUS'],
        },
        :variants => %w{
          6Server-optional-6.1.z
          6Server-6.1.z
          6Client-optional-6.1.z
          6Workstation-optional-6.1.z
          6ComputeNode-6.1.z
          6Client-6.1.z
          6ComputeNode-optional-6.1.z
          6Workstation-6.1.z
          6Server-HighAvailability-6.1.z
          6Server-ResilientStorage-6.1.z
          6Workstation-ScalableFileSystem-6.1.z
          6Server-LoadBalancer-6.1.z
          6Server-ScalableFileSystem-6.1.z
        }
      },
      196 => {
        :link_variants => {},
        :variants => %w{
          6Server-optional-6.1.EUS
          6Server-HighAvailability-6.1.EUS
          6Server-6.1.EUS
          6Server-ScalableFileSystem-6.1.EUS
          6Server-ResilientStorage-6.1.EUS
          6Server-LoadBalancer-6.1.EUS
        }
      },
    }
    linked_variant_test(ids)
  end

  test "shows variants linked by CDN repos" do
    auth_as admin_user

    # eliminate all channel links to test CDN-only links
    ProductVersion.find(345).channel_links.each(&:destroy)

    ids = {
      345 => {
        :link_variants => {
          '7Client-7.0.Z' => ['7Client'],
          '7Workstation-7.0.Z' => ['7Workstation'],
        },
        :variants => %w{
          7Client-7.0.Z
          7Client-optional-7.0.Z
          7ComputeNode-7.0.Z
          7ComputeNode-optional-7.0.Z
          7Server-7.0.Z
          7Server-HighAvailability-7.0.Z
          7Server-LoadBalancer-7.0.Z
          7Server-ResilientStorage-7.0.Z
          7Server-SAP-7.0.Z
          7Server-optional-7.0.Z
          7Workstation-7.0.Z
          7Workstation-optional-7.0.Z
        }
      },
    }
    linked_variant_test(ids)
  end

  test "shows variants linked by CDN repos and channel links" do
    auth_as admin_user

    # expects same results as CDN-only - all the CDN links are RHN links as well
    ids = {
      345 => {
        :link_variants => {
          '7Client-7.0.Z' => ['7Client'],
          '7Client-optional-7.0.Z' => ['7Client-optional'],
          '7ComputeNode-7.0.Z' => ['7ComputeNode'],
          '7ComputeNode-optional-7.0.Z' => ['7ComputeNode-optional'],
          '7Server-7.0.Z' => ['7Server'],
          '7Server-optional-7.0.Z' => ['7Server-optional'],
          '7Server-HighAvailability-7.0.Z' => ['7Server-HighAvailability'],
          '7Server-LoadBalancer-7.0.Z' => ['7Server-LoadBalancer'],
          '7Server-ResilientStorage-7.0.Z' => ['7Server-ResilientStorage'],
          '7Server-SAP-7.0.Z' => ['7Server-SAP'],
          '7Workstation-7.0.Z' => ['7Workstation'],
          '7Workstation-optional-7.0.Z' => ['7Workstation-optional'],
        },
        :variants => %w{
          7Client-7.0.Z
          7Client-optional-7.0.Z
          7ComputeNode-7.0.Z
          7ComputeNode-optional-7.0.Z
          7Server-7.0.Z
          7Server-HighAvailability-7.0.Z
          7Server-LoadBalancer-7.0.Z
          7Server-ResilientStorage-7.0.Z
          7Server-SAP-7.0.Z
          7Server-optional-7.0.Z
          7Workstation-7.0.Z
          7Workstation-optional-7.0.Z
        }
      },
    }
    linked_variant_test(ids)
  end

  def mock_errata_status
    # Fake errata to NEW_FILES or inactive state to prevent the validation
    # from raising error
    [ [RHEA, State::NEW_FILES],
      [RHSA, State::NEW_FILES],
      [RHBA, State::SHIPPED_LIVE],
    ].each do |klass, status|
      klass.any_instance.stubs(:status).returns(status)
    end
  end

  test 'unset push targets in product version level should also unset the variant push targets' do
    auth_as admin_user
    mock_errata_status

    product_version = ProductVersion.find_by_name('RHEL-7')
    variant = Variant.find_by_name('7Client')
    product_version_push_targets = product_version.push_targets
    variant_push_targets = variant.push_targets
    different = variant_push_targets - product_version_push_targets
    assert different.empty?, "Fixture error: variant contains push targets that are not supported by the product version."

    # Unset the product version push targets that are in use by the variant.
    # product version push targets = [a, b, c, d]
    # variant push targets = [c,d]
    # then unset [c,d]
    expected_push_targets = product_version_push_targets.reject{ |pvt| variant_push_targets.include?(pvt) }

    assert_difference("ActivePushTarget.count", variant_push_targets.count * -1) do
      post :update, :id => product_version.id, :product_version => { :push_targets => expected_push_targets}
    end

    assert_array_equal expected_push_targets, product_version_push_targets.reload
    assert variant_push_targets.reload.empty?
    assert_response :redirect
    assert_match(/Update succeeded/, flash[:notice])
  end

  test "add new channel" do
    auth_as admin_user
    pv = ProductVersion.find_by_name('RHEL-6')

    expected_name = [
      'rhel-x86_64-server-6-fast-test1',
      'rhel-x86_64-server-6-test1',
    ]

    expected_channels = [
      {:arch => "x86_64",
       :name => expected_name[0],
       :variant => "6Server",
       :type => "PrimaryChannel",},
      {:arch => "x86_64",
       :name => expected_name[1],
       :variant => "6Server",
       :type => "FastTrackChannel",},
    ].sort{|a,b| a[:name] <=> b[:name]}

    assert_difference(["Channel.count", "ChannelLink.count"], 2) do
      post :set_channels,
        :id => pv.id,
        :channels => expected_channels
    end

    actual_channels = Channel.last(2).sort_by(&:name)

    expected_name.count.times do |num|
      assert_channel_equal(expected_channels[num], actual_channels[num])
    end
    assert_response :redirect
    assert_match(/Added channels: #{expected_name.join(', ')}/, flash[:notice])
  end

  test 'view product version as json' do
    auth_as admin_user
    get :show, :id => 317, :format => :json
    assert_response :success, response.body

    assert_testdata_equal 'api/product_versions/show_317.json', canonicalize_json(response.body)
  end

  def assert_channel_equal(expected, actual)
    valid_constants = [:variant, :arch]
    assert expected, "Channel #{actual.name} not exists."
    expected.each_pair do |attr, val|
      if valid_constants.include?(attr)
        val = attr.to_s.classify.constantize.find_by_name(val)
      end
      assert_equal val, actual.send(attr)
    end
  end

  def linked_variant_test(testdata)
    testdata.each do |id,data|
      product_version = ProductVersion.find(id)
      product = product_version.product
      product_version_id = product_version.id

      get :show, :product_id => product.id.to_s, :id => product_version_id.to_s
      assert_response :success

      displayed_variants = response.body.scan(%r{
        ^\s*(Variant|Inherited\ from)[ ]
        .*?> ([^<]+) </a>
      }x)

      # nb: not testing for duplicates until bug 1024605 is fixed
      expected_variants = data[:variants].to_set
      expected_link_variants = data[:link_variants].clone
      suffix = <<-"eos".strip_heredoc
         for product version #{product_version.inspect}; expected variants:
        #{expected_variants.inspect}
        expected link variants:
        #{expected_link_variants.inspect}
      eos

      parent_variant = nil
      displayed_variants.each do |type,variant|
        if type == 'Variant'
          parent_variant = variant
          assert expected_variants.include?(variant), "Unexpectedly displayed non-inherited variant #{variant}#{suffix}"
        elsif type == 'Inherited from'
          expected_links = expected_link_variants[parent_variant]
          assert_not_nil expected_links, "Unexpectedly displayed linked variant #{variant}#{suffix}"
          assert expected_links.include?(variant), "Unexpectedly displayed #{variant} as inheriting from #{parent_variant}#{suffix}"
        else
          raise "invalid type #{type}"
        end
      end
    end
  end

end

require 'test_helper'

class CdnReposControllerTest < ActionController::TestCase

  setup do
    auth_as admin_user
    @request.env['HTTP_REFERER'] = 'http://test.example.com/ext_tests/1'
  end

  test "can not create cdn repository without a name" do
    post :create,
      :variant_id => Variant.first.id,
      :cdn_repo => {
        :type => CdnBinaryRepo.name,
        :arch_id => Arch.first.id,
        :name => ""
      }
    assert_response :success # (would be :unprocessable_entity for json requests)
    refute assigns[:cdn_repo].id.present?
    refute assigns[:cdn_repo].valid?
  end

  def test_create_existed_cdn_repo(format)
    repo = CdnBinaryRepo.find_by_name!('rhel-6-client-rpms__6Client__amd64')
    variant = Variant.find_by_name!('7Workstation-7.0.Z')
    assert_not_equal variant, repo.variant, 'testdata problem: must have a different variant'

    post :create,
      :format => format,
      :variant_id => variant,
      :cdn_repo => {
        :name => repo.name,
        # These don't matter.  Might make sense to do something with them later though.
        :arch_id => 2134,
        :type => 'SomeBogusType'
      }
    return repo, variant
  end

  test "creating repository with existing name will create a link - json" do
    auth_as admin_user

    repo = variant = nil
    assert_difference('CdnRepoLink.count') do
      (repo, variant) = test_create_existed_cdn_repo(:json)
      assert_json("CDN repository '#{repo.name}' has been attached to variant '#{variant.name}' successfully.", :created)
    end

    link = CdnRepoLink.last
    assert_equal repo, link.cdn_repo
    assert_equal variant, link.variant
  end

  test "attempt to create a duplicate repository should fail" do
    auth_as admin_user

    assert_no_difference('CdnRepo.count') do
      test_create_existed_cdn_repo(:html)
      assert_response :ok, response.body
      assert_match(/Name has already been taken/, response.body)
    end
  end

  [:attach, :link].each do |action|
    test "#{action} repository without calling create repository" do
      auth_as admin_user

      repo = CdnBinaryRepo.find_by_name!('rhel-6-client-rpms__6Client__amd64')
      variant = Variant.find_by_name!('7Workstation-7.0.Z')
      assert_not_equal variant, repo.variant, 'testdata problem: must have a different variant'

      assert_difference('CdnRepoLink.count') do
        post action, :id => repo.id, :variant_id => variant
        assert_response :redirect, response.body
        assert_nil flash[:error]
      end

      link = CdnRepoLink.last
      assert_equal repo, link.cdn_repo
      assert_equal variant, link.variant

      assert_equal "CDN repository '#{repo.name}' has been attached to variant '#{variant.name}' successfully.", flash[:notice]
    end
  end

  def test_delete_repo_without_link(format)
    auth_as admin_user
    repo = CdnRepo.find_by_name('rhel-6-client-rpms__6Client__i686')
    assert_equal 1, repo.cdn_repo_links.count, "testdata problem: test data could be changed."
    assert_equal repo.variant.name, repo.cdn_repo_links[0].variant.name, "testdata problem: variant not match"

    assert_difference(['CdnRepo.count', 'CdnRepoLink.count'], -1) do
      post :destroy, :id => repo.id, :variant_id => repo.variant_id, :format => format
    end

    if format == :json
      assert_testdata_equal "api/cdn_repos/delete_cdn_repo_without_links.json", formatted_json_response
    else
      status = format == :html ? :redirect : :success
      message = "CDN repository \'#{repo.name}\' has been deleted successfully"
      self.send("assert_#{format}", message, status)
    end
  end

  def test_delete_repo_with_links(format)
    auth_as admin_user
    repo = CdnRepo.find_by_name('rhel-6-server-rpms__6Server__x86_64')
    assert repo.cdn_repo_links.count > 1, "testdata problem: test data could be changed."

    assert_no_difference(['CdnRepo.count', 'CdnRepoLink.count']) do
      post :destroy, :id => repo.id, :variant_id => repo.variant_id, :format => format
    end

    if format == :json
      assert_testdata_equal "api/cdn_repos/delete_cdn_repo_with_links.json", formatted_json_response
    else
      message = "CDN repository \'#{repo.name}\' is attached to multiple variants: 6Server-6\.5\.z\."
      self.send("assert_#{format}", message, :bad_request)
    end
  end

  [:json, :html].each do |format|
    # Test unlink CDN Repository
    [:unlink, :detach, :destroy].each do |action|
      test "#{action} repository - #{format}" do
        auth_as admin_user

        repo = CdnRepo.find_by_name('rhel-6-server-rpms__6Server__x86_64')
        variant = Variant.find_by_name('6Server-6.5.z')
        assert repo.cdn_repo_links.count > 1, "testdata problem: test data could be changed."
        message = "CDN repository '#{repo.name}' has been detached with variant '#{variant.name}' successfully."

        assert_difference('CdnRepoLink.count', -1) do
          post action, :id => repo.id, :variant_id => variant, :format => format
        end
        assert CdnRepo.exists?(:name => repo.name)

        status = format == :html ? :redirect : :success
        self.send("assert_#{format}", message, status)
      end

      test "#{action} repository without link should fail - #{format}" do
        auth_as admin_user

        repo = CdnRepo.find_by_name('rhel-6-server-rpms__6Server__x86_64')
        variant = Variant.find_by_name('7Server')
        assert repo.cdn_repo_links.count > 1, "testdata problem: test data could be changed."
        message = "The selected CDN repositories don't attach to variant '#{variant.name}'."

        assert_no_difference(['CdnRepo.count','CdnRepoLink.count']) do
          post action, :id => repo.id, :variant_id => variant,  :format => format
        end

        self.send("assert_#{format}", message, :not_found)
      end
    end

    # Test delete CDN Repository
    test "delete repository with no links to others via - #{format}" do
      test_delete_repo_without_link(format)
    end

    test "delete repository with links to others should get error - #{format}" do
      test_delete_repo_with_links(format)
    end
  end

  def assert_html(expected_message, expected_status)
    assert_response expected_status, response.body
    if expected_status != :redirect
      assert_match(/#{ERB::Util.html_escape(expected_message)}/, response.body)
    else
      assert_match(/#{expected_message}/, flash[:notice])
    end
  end

  def assert_json(expected_message, expected_status)
    data = JSON.load(response.body)
    if expected_status != :success && expected_status != :created
      message = data['error']
    else
      message = data['notice']
    end
    assert_response expected_status, response.body
    assert_match(/#{expected_message}/, message)
  end

  test "update CDN repository" do
    auth_as admin_user

    repo = CdnBinaryRepo.find_by_has_stable_systems_subscribed(true)
    # hmm...both post and put work here
    put :update,
      :id => repo.id,
      :variant_id => repo.variant_id,
      :cdn_repo => {
        :arch_id => repo.arch_id,
        :has_stable_systems_subscribed => 0
      }
    assert_response :redirect, response.body
    assert_nil flash[:error]

    repo.reload
    refute repo.has_stable_systems_subscribed
    assert_equal "CDN repository 'cdnrepo-alpha' was successfully updated.", flash[:notice]
  end

  test "can create a cdn repo without specifying release_type" do
    create_repo_test
  end

  test "can create a cdn repo with a specified release_type" do
    create_repo_test("FastTrackCdnRepo")
  end

  def create_repo_test(release_type=nil)
    variant = Variant.first
    arch = Arch.first

    cdn_repo_attrs = {
      :type => 'CdnBinaryRepo',
      :arch_id => arch.id,
      :name => "blah" }
    cdn_repo_attrs.merge!(:release_type => release_type) if release_type

    post :create, :variant_id => variant.id, :cdn_repo => cdn_repo_attrs

    cdn_repo = assigns[:cdn_repo]
    assert cdn_repo.id.present?, "cdn repo not created!"
    assert_redirected_to :action => :show, :id => cdn_repo.id
    assert_valid cdn_repo
    assert_equal (release_type || "PrimaryCdnRepo"), cdn_repo.release_type
    assert_equal variant.id, cdn_repo.variant_id
    assert_equal arch.id, cdn_repo.arch_id
    assert_equal "blah", cdn_repo.name
  end

  test "index includes directly associated cdn repos - html" do
    index_names_test :variant_id => 339, :expected_names => %w[
      rhel-6-server-optional-rpms__6Server__ppc64
      rhel-6-server-optional-rpms__6Server__x390x
      rhel-6-server-optional-rpms__6Server__x86_64
      rhel-6-server-optional-rpms__6Server__i386
    ]
  end

  test "index includes directly associated cdn repos - json" do
    index_names_test :variant_id => 339, :format => :json, :expected_names => %w[
      rhel-6-server-optional-rpms__6Server__ppc64
      rhel-6-server-optional-rpms__6Server__x390x
      rhel-6-server-optional-rpms__6Server__x86_64
      rhel-6-server-optional-rpms__6Server__i386
    ]
  end

  test "index includes linked cdn repos - html" do
    # this is a 7.0.Z variant which links to the main 7 repos
    index_names_test :variant_id => 842, :expected_names => %w[
      rhel-7-desktop-rpms__7Client__x86_64
      rhel-7-desktop-debug-rpms__7Client__x86_64
      rhel-7-desktop-source-rpms__7Client__x86_64
    ]
  end

  test "index includes linked cdn repos - json" do
    index_names_test :variant_id => 842, :format => :json, :expected_names => %w[
      rhel-7-desktop-rpms__7Client__x86_64
      rhel-7-desktop-debug-rpms__7Client__x86_64
      rhel-7-desktop-source-rpms__7Client__x86_64
    ]
  end

  # Bug 1097727
  [:html, :json].each do |fmt|
    test "index doesn't include unrelated repos in linked variants - #{fmt}" do
      rhel7_variant = Variant.find_by_name!('7Client')
      rhel6_repo = CdnRepo.find_by_name!('rhel-6-client-rpms__6Client__i586')
      CdnRepoLink.create!(
        :cdn_repo => rhel6_repo,
        :variant => rhel7_variant,
        :product_version => rhel7_variant.product_version
      )
      index_names_test :variant_id => rhel7_variant, :format => fmt, :expected_names => %w[
        rhel-7-desktop-rpms__7Client__x86_64
        rhel-7-desktop-debug-rpms__7Client__x86_64
        rhel-7-desktop-source-rpms__7Client__x86_64
        rhel-7-desktop-fastrack-debug-rpms__x86_64
        rhel-7-desktop-fastrack-rpms__x86_64
        rhel-7-desktop-fastrack-source-rpms__x86_64
        rhel-6-client-rpms__6Client__i586
      ]

      # html check tests for presence of names only, not absence.
      # check ourselves that no other RHEL6 names were present
      if fmt == :html
        assert_equal ['rhel-6-client-rpms__6Client__i586'], response.body.scan( %r{\brhel-6[^<]+\b} )
      end
    end
  end

  def index_names_test(args)
    expected_names = args.delete(:expected_names)
    expected_keys = %w[id type release_type name has_stable_systems_subscribed variant arch].sort

    get :index, args
    assert_response :success

    if args[:format] == :json
      data = JSON.load(response.body)
      assert_array_equal data.map{|x| x['name']}.sort, expected_names.sort
      data.each { |x| assert_array_equal expected_keys, x.keys.sort }
    else
      expected_names.each do |name|
        assert_match %r{\b#{Regexp.escape name}\b}, response.body
      end
    end
  end

  test "search by keyword returns only repositories with the same X stream" do
    pv = ProductVersion.find_by_name!("RHEL-6.6.z")
    get :search_by_keyword, :name => 'server', :product_version_id => pv, :format => :json

    JSON.load(response.body).each do |cdn_repo|
      assert_match(/^rhel-6-server/, cdn_repo["name"])
    end
  end

  test "request js attach form" do
    get :attach_form, :format => :js, :variant_id => Variant.find_by_name!("6Server")
    assert_response :ok
    assert_match(/Attach CDN repository to 6Server/, response.body)
    assert_match(/Please enter CDN repository to be attached:/, response.body)
    # has save button
    assert_match(/Save/, response.body)
  end

  test "search packages for autocomplete" do
    get :search_packages, :format => :json, :id => 3001, :name => 'docker'
    assert_response :ok
    result = JSON.load(response.body)
    assert result.kind_of?(Array)
    package_names = result.map{ |x| x['name'] }
    package_names.concat CdnRepo.find(3001).packages.pluck(:name)
    package_names.sort!
    assert_equal package_names, Package.where("name LIKE '%docker%'").pluck(:name)
  end

  test "mapping non-existent package creates package" do
    cdn_repo = CdnRepo.find(3001)

    # Package with this name does not exist
    package_name = 'not_a_package'
    assert_nil Package.find_by_name(package_name)

    # Create package mapping should still be successful
    assert_difference('cdn_repo.packages.count', 1) do
      post :create_package_mapping, :id => cdn_repo.id, :package => { :name => package_name }
      assert_response :redirect
      assert_match /is now mapped to repository/, flash[:notice]
    end

    # Package has been created
    assert_not_nil Package.find_by_name(package_name)
  end

  test "map package to repository" do
    cdn_repo = CdnRepo.find(3001)
    assert_difference('cdn_repo.packages.count', 1) do
      post :create_package_mapping, :id => 3001, :package => { :name => 'rh-python34-docker' }
      assert_response :redirect
      assert_match /is now mapped to repository/, flash[:notice]
    end
  end

  test "remove package from repository" do
    cdn_repo = CdnRepo.find(3001)
    assert_difference('cdn_repo.packages.count', -1) do
      post :delete_package_mapping, :id => cdn_repo.id, :package_id => 31611
      assert_response :redirect
      assert_match /Package mapping has been removed/, flash[:notice]
    end
  end

  test 'disallow removing mapping if being used by errata IN_PUSH' do
    erratum = Errata.find(21130)
    erratum.change_state!(State::IN_PUSH, admin_user)
    assert erratum.has_docker?
    mapping = CdnRepoPackage.find(3)
    assert mapping.get_advisories_using_mapping.include?(erratum)
    pkg = mapping.package
    cdn_repo = mapping.cdn_repo
    # deletion must fail because erratum is currently using this cdn repo
    assert_no_difference('cdn_repo.packages.count') do
      post :delete_package_mapping, :id => cdn_repo.id, :package_id => pkg.id
      assert_response :redirect
      assert_match /Error: CDN repo package mapping with package rhel-server-docker is currently in use by<br>RHBA-2015:2398-17/, flash[:error]
    end

    # update status to previous one
    erratum.change_state!(State::PUSH_READY, admin_user)
    # try again. it should be successful now.
    assert_difference('cdn_repo.packages.count', -1) do
      post :delete_package_mapping, :id => cdn_repo.id, :package_id => pkg.id
      assert_response :redirect
      assert_match /Package mapping has been removed/, flash[:notice]
    end
  end

  test "get package tags" do
    get :package_tags, :id => 3001, :package_id => 31611
    assert_response :ok
    assert_match(/perl520-\{\{release\}\}/, response.body)
    assert_match(/rh-perl520-\{\{version\}\}/, response.body)

    # admin_user can see Add and Delete buttons
    assert_match(/btn-add/, response.body)
    assert_match(/btn-delete/, response.body)
  end

  test "get package tags as devel user" do
    auth_as devel_user
    get :package_tags, :id => 3001, :package_id => 31611
    assert_response :ok
    assert_match(/perl520-\{\{release\}\}/, response.body)
    assert_match(/rh-perl520-\{\{version\}\}/, response.body)

    # devel_user not shown Add and Delete buttons
    assert_no_match(/btn-add/, response.body)
    assert_no_match(/btn-delete/, response.body)
  end

  test "add package tag" do
    assert_difference('CdnRepoPackageTag.count', 1) do
      post :add_package_tag, :cdn_repo_package_id => 1, :tag_template => '__new_tag_template__'
      assert_response :redirect
      assert_match /Tag template .* has been added/, flash[:notice]
    end
  end

  test "remove package tag" do
    assert_difference('CdnRepoPackageTag.count', -1) do
      post :remove_package_tag, :cdn_repo_package_tag_id => 1
      assert_response :redirect
      assert_match /Tag template .* has been removed/, flash[:notice]
    end
  end

  test 'disallow removing cdn repo in use for multi product mappings' do
    pv = ProductVersion.find(252)
    variant = pv.variants.last
    # prepare new cdn repo to make sure it doesn't have any other dependencies
    # or constraints
    ['test_cdn_repo_1', 'test_cdn_repo_2'].each do |name|
      CdnRepo.create(:name => name,
                     :release_type => 'PrimaryCdnRepo',
                     :type => 'CdnSourceRepo',
                     :variant_id => variant.id,
                     :arch_id => 4,
                     :product_version => pv)
    end
    c1, c2 = CdnRepo.last(2)
    map = MultiProductCdnRepoMap.create(:package => Package.find(14685),
                                        :origin_cdn_repo => c1,
                                        :origin_product_version => c1.product_version,
                                        :destination_cdn_repo => c2,
                                        :destination_product_version => c2.product_version,
                                        :user => admin_user)
    # multi product map uses the cdn repos so can't delete the cdn repos
    [ c1, c2 ].each do |cdn_repo|
      assert_no_difference('CdnRepo.count') do
        assert_no_difference('MultiProductCdnRepoMap.count') do
          delete :destroy,
                 :id => cdn_repo,
                 :product_version_id => cdn_repo.product_version
          assert_response :bad_request
          expected_message = "CDN repository &#x27;#{cdn_repo.name}&#x27; is depending by multi product mapped"
          assert_match(/#{Regexp.escape(expected_message)}/, response.body)
        end
      end
    end
    map.destroy
    # multi product mapping is removed so can delete the cdn repos
    [ c1, c2 ].each do |cdn_repo|
      assert_difference('CdnRepo.count', -1) do
        delete :destroy,
               :id => cdn_repo,
               :product_version_id => cdn_repo.product_version
        assert_response :redirect
        assert_equal "#{cdn_repo.class.display_name} '#{cdn_repo.name}' has been deleted successfully.", flash[:notice]
      end
    end
  end

end

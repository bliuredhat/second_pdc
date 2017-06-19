require 'test_helper'

class NoauthErrataControllerTest < ActionController::TestCase
  tests Noauth::ErrataController

  setup do
    @errata = Errata.first
    @test_formats = [:json, :text, :xml]
    @qe_advisory = Errata.find(11065)
    @channel_links = ChannelLink.limit(2)
    @released_packages = ReleasedPackage.where(:id => [1045328, 1045329, 1045331, 1045339])
    @errata_brew_maps = ErrataBrewMapping.limit(1)
    @cdn_repos = CdnRepo.limit(2)
    @brew_rpms = BrewRpm.limit(4)
    @channels = Channel.limit(2)
  end

  def assert_text_equal(expected_data)
    assert_equal expected_data.strip, response.body.strip
  end

  def assert_json_equal(expected_data)
    response_results = ActiveSupport::JSON.decode(response.body).to_s
    expected_results = expected_data.to_s
    assert_equal expected_results, response_results
  end

  def assert_xml_equal(expected_data)
    response_results = Hash.from_xml(response.body)
    assert_equal expected_data, response_results
  end

  def get_expected_pulp_data(data, format)
    if format == :xml
      if data.count == 1
        repos = {'idname' => data.keys[0], 'file' => data.values[0]}
      else
        repos = []
        data.each_pair do |cdn_repo,rpms|
          repos << {'idname' => cdn_repo, 'file' => rpms}
        end
      end
      return {'pulp_packages' => {'errata' => @errata.id.to_s, 'repo' => repos}}
    elsif format == :text
      rows = []
      data.each_pair do |k,v|
        rows << [k].concat(v).join(',')
      end
      return rows.join("\n")
    elsif format == :json
      return data
    else
      raise ArgumentError, "Invalid format '#{format}'"
    end
  end

  def get_expected_channel_data(data, format)
    if format == :xml
      if data.count == 1
        channels = {'channel' => data.keys[0], 'file' => data.values[0]}
      else
        channels = []
        data.each_pair do |channel,rpms|
          channels << {'channel' => channel, 'file' => rpms}
        end
      end
      return {'channel_packages' => {'errata' => @errata.id.to_s, 'channel' => channels}}
    elsif format == :text
      rows = []
      data.each_pair do |k,v|
        rows << [k].concat(v).join(',')
      end
      return rows.join("\n")
    elsif format == :json
      return data
    else
      raise ArgumentError, "Invalid format '#{format}'"
    end
  end

  def do_get(url, format, params = {})
    get url, params.merge({:format => format})
  end

  test "get blocking errata" do
    @errata = Errata.find(18917)
    expected = @errata.blocking_errata.collect{|e| e.shortadvisory}

    get :blocking_errata_for, :format => :json, :id => @errata.id

    assert_response :success
    assert_equal expected, ActiveSupport::JSON.decode(response.body)
  end

  test "get depending errata" do
    @errata = Errata.find(18917)
    expected = @errata.dependent_errata.collect{|e| e.shortadvisory}

    get :depending_errata_for, :format => :json, :id => @errata.id

    assert_response :success
    assert_equal expected, ActiveSupport::JSON.decode(response.body)
  end

  test "can export tps.txt" do
    get :get_tps_txt, :id => @qe_advisory.id
    assert_response :success
    assert response.body.present?
  end

  test "get channel packages" do
    rpm_list = @brew_rpms.all.sort{|a,b| a.file_path <=> b.file_path}

    mock_results = {
      @channels[0].name => rpm_list[0..1].map(&:file_path),
      @channels[1].name => rpm_list[2..3].map(&:file_path)
    }

    @test_formats.each do |format|
      expected_data = get_expected_channel_data(mock_results, format)
      Push::Rhn.expects(:get_packages_by_errata).once.with(@errata).returns(mock_results)

      do_get(:get_channel_packages, format, {:id => @errata.id})
      assert_response :success
      assert response.body.present?
      send("assert_#{format.to_s}_equal", expected_data)
    end
  end

  test "get channel packages of a single channel" do
    rpm_list = @brew_rpms.all.sort!{|a,b| a.file_path <=> b.file_path}
    search_channel = @channels[0]

    mock_results = {
      search_channel.name => rpm_list[0..1].map(&:file_path),
    }

    @test_formats.each do |format|
      expected_data = get_expected_channel_data(mock_results, format)
      Push::Rhn.expects(:get_packages_by_errata).once.with(@errata, search_channel).returns(mock_results)

      do_get(:get_channel_packages, format, {:id => @errata.id, :channel => search_channel.name})
      assert_response :success
      assert response.body.present?
      send("assert_#{format.to_s}_equal", expected_data)
    end
  end

  test 'get released channel packages' do
    channel_list = @channels.to_a
    released_rpms = @released_packages.to_a
    mock_results = {
      channel_list[0].name => released_rpms[0..1].map(&:full_path).sort,
      channel_list[1].name => released_rpms[2..3].map(&:full_path).sort
    }

    @test_formats.each do |format|
      expected_data = get_expected_channel_data(mock_results, format)
      Push::Rhn.expects(:get_released_packages_by_errata).once.with(@errata).returns(mock_results)

      do_get(:get_released_channel_packages, format, {:id => @errata.id})
      assert_response :success
      assert response.body.present?
      send("assert_#{format.to_s}_equal", expected_data)
    end
  end

  test 'get released channel packages of a single channel' do
    channel = @channels.first
    mock_results = {
      channel.name => @released_packages.map(&:full_path).sort
    }

    @test_formats.each do |format|
      expected_data = get_expected_channel_data(mock_results, format)
      Push::Rhn.expects(:get_released_packages_by_errata).once.with(@errata, channel).returns(mock_results)

      do_get(:get_released_channel_packages, format, {:id => @errata.id, :channel => channel.name})
      assert_response :success
      assert response.body.present?
      send("assert_#{format.to_s}_equal", expected_data)
    end
  end

  test 'get pulp packages' do
    cdn_repo_list = @cdn_repos.map(&:name).sort
    rpm_list = @brew_rpms.map(&:file_path).sort
    mock_results = {
      cdn_repo_list[0] => rpm_list[0..1],
      cdn_repo_list[1] => rpm_list[2..3]
    }

    @test_formats.each do |format|
      expected_data = get_expected_pulp_data(mock_results, format)
      Push::Cdn.expects(:get_packages_by_errata).once.with(@errata).returns(mock_results)
      do_get(:get_pulp_packages, format, {:id => @errata.id})
      assert_response :success
      assert response.body.present?
      send("assert_#{format.to_s}_equal", expected_data)
    end
  end

  test 'get released pulp packages' do
    cdn_repo_list = @cdn_repos.map(&:name).sort
    rpm_list = @released_packages.map(&:full_path).sort
    mock_results = {
      cdn_repo_list[0] => rpm_list[0..1],
      cdn_repo_list[1] => rpm_list[2..3]
    }

    @test_formats.each do |format|
      expected_data = get_expected_pulp_data(mock_results, format)
      Push::Cdn.expects(:get_released_packages_by_errata).once.with(@errata).returns(mock_results)
      do_get(:get_released_pulp_packages, format, {:id => @errata.id})
      assert_response :success
      assert response.body.present?
      send("assert_#{format.to_s}_equal", expected_data)
    end
  end

  test 'get pulp packages of a single cdn repo' do
    cdn_repo= @cdn_repos.first
    mock_results = {
      cdn_repo.name => @brew_rpms.map(&:file_path).sort,
    }

    @test_formats.each do |format|
      expected_data = get_expected_pulp_data(mock_results, format)
      Push::Cdn.expects(:get_packages_by_errata).once.with(@errata, cdn_repo).returns(mock_results)
      do_get(:get_pulp_packages, format, {:id => @errata.id, :repo => cdn_repo.name})
      assert_response :success
      assert response.body.present?
      send("assert_#{format.to_s}_equal", expected_data)
    end
  end

  test 'get released pulp packages of a single cdn repo' do
    cdn_repo = @cdn_repos.first
    mock_results = {
      cdn_repo.name => @released_packages.map(&:full_path).sort,
    }

    @test_formats.each do |format|
      expected_data = get_expected_pulp_data(mock_results, format)
      Push::Cdn.expects(:get_released_packages_by_errata).once.with(@errata, cdn_repo).returns(mock_results)
      do_get(:get_released_pulp_packages, format, {:id => @errata.id, :repo => cdn_repo.name})
      assert_response :success
      assert response.body.present?
      send("assert_#{format.to_s}_equal", expected_data)
    end
  end

  test 'get_released_packages returns error if version is missing' do
    params = { :id => @errata, :format => :text, :arch => Arch.last.name }
    [{}, {:version => 'bogus'}].each do |version_param|
      get :get_released_packages, params.merge(version_param)
      assert_response :bad_request
      assert_match "ERROR: Can't find variant '#{version_param[:version]}'!", response.body
    end
  end

  test 'get_released_packages returns error if arch is missing' do
    params = { :id => @errata, :format => :text, :version => Variant.last.name }
    [{}, {:arch => 'bogus'}].each do |arch_param|
      get :get_released_packages, params.merge(arch_param)
      assert_response :bad_request
      assert_match "ERROR: Can't find arch '#{arch_param[:arch]}'!", response.body
    end
  end

  test 'get_released_packages returns list of packages successfully' do
    advisory = Errata.find(11131)
    get :get_released_packages,
      :id => advisory,
      :format => :text,
      :version => advisory.variants.first.name,
      :arch => 'i386'
    assert_response :success
    assert assigns(:files).any?

    file = assigns(:files).first
    assert_match file, response.body
  end

  test 'get_released_packages returns source rpms only with additional parameters' do
    advisory = Errata.find(11129)

    get :get_released_packages,
      :id => advisory,
      :want_src => 1,
      :format => :text,
      :version => advisory.variants.first.name,
      :arch => 'x86_64'
    assert_response :success
    assert_equal 1, assigns(:files).count
    assert_match %r{.*\.src\.rpm$}, assigns(:files).last
  end

  test 'get released channel packages compare against baseline' do
    with_baselines('get_released_channel_packages', %r{/(\d+)\.json$}) do |_,id|
      get :get_released_channel_packages, :format => :json, :id => id
      assert_response :success
      canonicalize_json(response.body)
    end
  end

  test 'get released pulp packages compare against baseline' do
    with_baselines('get_released_pulp_packages', %r{/(\d+)\.json$}) do |_,id|
      get :get_released_pulp_packages, :format => :json, :id => id
      assert_response :success
      canonicalize_json(response.body)
    end
  end

  test 'system version' do
    with_stubbed_const({:VERSION => '1.2.3'}, SystemVersion) do
      get :system_version, :format => :json
      assert_response :success
      assert_equal '1.2.3', response.body
    end
  end

end

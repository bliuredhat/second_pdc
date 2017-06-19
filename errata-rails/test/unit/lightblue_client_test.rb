require 'test_helper'

class LightblueClientTest < ActiveSupport::TestCase

  LB_DEV0_URL = 'https://datasvc.lightblue.dev0.redhat.com/rest/data/'.freeze

  teardown do
    fake_cert_file.close
  end

  test 'fetch nvra given a brew build' do
    client = errata_lightblue_client
    nvra_list = VCR.use_cassette fixture_name do
      client.container_image.nvra_for_brew_build('rh-ror41-docker-4.1-13.1')
    end

    assert_equal Array, nvra_list.class
    assert nvra_list.length > 20
    assert nvra_list.first.key?(:nvra)
    expected_nvra_list = %w(
        ca-certificates-2015.2.6-70.1.el7_2.noarch
        tzdata-2016a-1.el7.noarch
        glibc-devel-2.17-106.el7_2.4.x86_64
        glibc-common-2.17-106.el7_2.4.x86_64
        glibc-2.17-106.el7_2.4.x86_64
        glibc-headers-2.17-106.el7_2.4.x86_64
    )
    assert (expected_nvra_list - nvra_list.map {|record| record[:nvra]}).empty?
  end

  test 'fetch nvra using new certs' do
    client = errata_lightblue_client
    # NOTE: certs must be present at the time http request/response
    # is recorded by vcr
    client.cert_file = '~/.errata/certs/lightblue.crt.pem'
    client.cert_key_file = '~/.errata/certs/lightblue.key.pem'

    nvra_list = VCR.use_cassette 'lb_new_cert' do
      client.container_image.nvra_for_brew_build('rh-ror41-docker-4.1-13.1')
    end

    assert_equal Array, nvra_list.class
    assert nvra_list.length > 20
    assert nvra_list.first.key?(:nvra)
    nvra_only = nvra_list.map { |record| record[:nvra] }

    # NOTE: sample_nvra_list is a random sample taken from the
    # actual list (nvra_list) so it is smaller than the actual thus
    # sample_nvra_list - nvra_list should be []

    sample_nvra_list = %w(
      ca-certificates-2015.2.6-70.1.el7_2.noarch
      tzdata-2016a-1.el7.noarch
      glibc-devel-2.17-106.el7_2.4.x86_64
      glibc-common-2.17-106.el7_2.4.x86_64
      glibc-2.17-106.el7_2.4.x86_64
      glibc-headers-2.17-106.el7_2.4.x86_64
    )

    # assert_equal [], list will pretty-print the diff between
    # [] and actual making it easy to indentify what has changed
    assert_equal [], (sample_nvra_list - nvra_only)
  end

  test 'repositories_for_brew_builds' do
    build_nvrs = [
      "openshift-sti-nodejs-docker-0.10-43",
      "openshift-sti-perl-docker-5.16-45"
    ]
    client = errata_lightblue_client
    response = VCR.use_cassette fixture_name do
      client.container_image.repositories_for_brew_builds(build_nvrs)
    end

    assert_equal Array, response.class
    assert_equal build_nvrs.length, response.length
    [:lastUpdateDate, :brew, :repositories].each do |key|
      assert response.first.key?(key)
    end
  end

  ### validation errors ###

  test 'invalid data_url raises error' do
    assert_raise Lightblue::ConfigError do
      Lightblue::Client.new(:data_url => 'ftp://example.com')
    end
  end

  test 'no cert raises CertError' do
    non_existing_file = '/tmp/non/existing/file'
    assert_equal false, File.file?(non_existing_file)

    assert_raise Lightblue::CertError do
      Lightblue::Client.new(
        :data_url  => 'https://example.com',
        :cert_file => non_existing_file
      )
    end
  end

  test 'non-existing key raises CertKeyError' do
    non_existing_file = '/tmp/non/existing/file'
    assert_equal false, File.file?(non_existing_file)

    assert_raise Lightblue::CertKeyError do
      Lightblue::Client.new(
        :data_url  => 'https://example.com',
        :cert_file => fake_cert_file.path,
        :cert_key_file => non_existing_file
      )
    end
  end

  test 'raises ClientError on invalid cert' do

    client = errata_lightblue_client
    client.cert_file = fake_cert_file


    err = VCR.use_cassette fixture_name do
      assert_raise Lightblue::ClientError do
        client.container_image.nvra_for_brew_build('foobar')
      end
    end

    assert_equal 0, err.response[:code]
    # cannot assert the ssl cert error message as VCR does not
    # capture error message that curl generates internally
  end

  test 'can raise forbidden error' do
    # raise forbidden error when acessing resource from a
    # lightblue server using a cert that is valid for a different
    # lightblue instance server

    client = errata_lightblue_client
    client.data_url = 'https://lightbluemetadatasvc.qa.a1.vary.redhat.com/rest/metadata/'

    err = VCR.use_cassette fixture_name do
      assert_raise Lightblue::ResourceForbiddenError do
        client.container_image.nvra_for_brew_build('foobar')
      end
    end

    msg = err.response[:error]
    assert_match %r(Access to the requested resource has been denied), msg
    assert_equal 403, err.response[:code]
  end

  test 'nvra for non existing brew build is empty' do
    client = errata_lightblue_client
    nvra_list = VCR.use_cassette fixture_name do
    ci = client.container_image
      ci.nvra_for_brew_build('foobar')
    end
    assert nvra_list.empty?
  end

  test 'can fetch data url ending in slash' do
    client = errata_lightblue_client
    client.data_url = LB_DEV0_URL
    assert client.data_url.ends_with? '/',
          "data_url #{client.data_url} must end in /"

    nvra_list = nil
    VCR.use_cassette fixture_name do
      ci = client.container_image

      # earlier when the data_url used in end with '/', lightblue client
      # used to fetch: <data-url>//find/containerImage
      # instead of:    <data-url>/find/containerImage
      # which raised an exception (404)
      assert_nothing_raised do
       nvra_list = ci.nvra_for_brew_build('foobaz')
      end
    end
    assert nvra_list.empty?
  end

  private

    # Lightblue errata client with validation suppressed since
    # the cert is absent
    def errata_lightblue_client
      Lightblue::ErrataClient.any_instance.expects(:validate).returns(nil)
      Lightblue::ErrataClient.new
    end

    # lightblue client with an invalid cert
    def lightblue_client
      config = LightblueConf::VALUES.merge(
        :cert_file => fake_cert_file.path,
        :logger => Rails.logger
      )
      Lightblue::Client.new(config)
    end

    def fake_cert_file
      @cert_file ||= Tempfile.new('lightbluetest')
    end
end

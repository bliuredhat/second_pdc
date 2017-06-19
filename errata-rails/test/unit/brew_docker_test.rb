require 'test_helper'
require 'brew'

class BrewDockerTest < ActiveSupport::TestCase

  def mock_brew_import(filename)
    params = JSON.load(File.read("#{Rails.root}/test/data/brew/#{filename}.json"))

    proxy = mock('Proxy')
    proxy.expects(:getBuild).returns(params['getBuild'])
    proxy.expects(:listBuildRPMs).returns([])
    proxy.expects(:listArchives).times(2).returns([])
    proxy.expects(:listArchives).returns(params['listArchives'])

    if params['getTaskInfo']
      proxy.expects(:getTaskInfo).returns(params['getTaskInfo'])
    end

    if params['getTaskRequest']
      proxy.expects(:getTaskRequest).returns(params['getTaskRequest'])
    end

    server = mock('Server')
    server.expects(:proxy).returns(proxy)

    XMLRPC::Client.expects(:new2).returns(server)
    connection = Brew.get_connection
    Brew.expects(:get_connection).at_least(3).returns(connection)
  end

  #
  # Build tasks with a "buildContainer" method are docker builds
  # http://brew-test.devel.redhat.com/brew/buildinfo?buildID=428265
  #
  test "buildContainer import" do
    mock_brew_import 'rsyslog-docker'
    b = BrewBuild.make_from_rpc_without_mandatory_srpm('rsyslog-docker-7.1-5.6.a')
    assert b.has_docker?
  end

  #
  # Tar files with a "docker" key in "extra" are docker images
  # http://brew-test.devel.redhat.com/brew/buildinfo?buildID=428339
  #
  test "docker file import" do
    mock_brew_import 'docker-hello-world'
    b = BrewBuild.make_from_rpc_without_mandatory_srpm('docker-hello-world-1.0-25')
    assert b.has_docker?
  end

  #
  # Builds with "image" method and "format" => ["docker"] are docker builds
  #
  test "image task with docker format import" do
    mock_brew_import 'rhel-server-docker'
    b = BrewBuild.make_from_rpc_without_mandatory_srpm('rhel-server-docker-6.8.24')
    assert b.has_docker?
  end

end

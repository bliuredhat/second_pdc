require 'test_helper'

class CovscanTest< ActiveSupport::TestCase
  fixtures :external_test_types

  setup do
    @test_run = rhba_async.create_external_test_run_for(:covscan, :external_id => 123)
  end

  test "covscan test runs" do
    # Grab an errata for testing
    @errata = RHBA.last

    # Stub a fake covscan client
    covscan_client_stub = stub(:create_errata_diff_scan => {'status'=>'OK', 'id'=>321})
    XMLRPC::CovscanClient.stubs(:instance).returns(covscan_client_stub)

    assert @errata.build_mappings.count > 0

    # In reality the observer will automatically call this when
    # an ErrataBrewMapping is created. Here we will do it manually.
    errata_brew_mapping = @errata.build_mappings.first
    CovscanCreateObserver.create_covscan_run_maybe(errata_brew_mapping)

    # Did nothing because covscan is not a required test (yet)
    assert_equal 0, @errata.current_external_test_runs_for(:covscan).count

    # This is why it did nothing..
    refute @errata.requires_external_test?(:covscan)

    # Now Make covscan a required test.
    @errata.state_machine_rule_set.test_requirements = ['covscan'].to_set
    @errata.state_machine_rule_set.save!

    # It will require covscan test
    assert @errata.requires_external_test?(:covscan)

    errata_brew_mapping = @errata.build_mappings.first # (refresh so not cached)
    assert errata_brew_mapping.errata.requires_external_test?(:covscan)

    # Do it again
    CovscanCreateObserver.create_covscan_run_maybe(errata_brew_mapping)

    # Should have a scan record now.
    assert_equal 1, @errata.external_test_runs_for(:covscan).count
    assert_equal 1, @errata.current_external_test_runs_for(:covscan).count

    # Do some sanity checks on it
    @covscan_run = @errata.current_external_test_runs_for(:covscan).first
    assert_equal 321, @covscan_run.external_id
    assert_equal 'PENDING', @covscan_run.status
    assert_equal @errata, @covscan_run.errata
    assert_equal 'covscan', @covscan_run.external_test_type.name
    refute @errata.all_external_test_runs_passed?

    # Simulate a message bus message arriving.
    # (Currently this doesn't properly test the handler code. I'm writing this
    # test on Fedora where cqpid doesn't exist, so I can't load QpidHandler.
    # Could refactor so this handler method isn't part of QpidHandler, BUT..
    # it's not simple. For example logging becomes quite messy. So decided to
    # just fake it a bit here. Also I don't want risk breaking things in the
    # abidiff listener/handler.

    ## Ideally would do something like this:
    ##MessageBus::QpidHandler.new.covscan_handle_message({'scan_state'=>'PASSED', 'scan_id'=>321})

    ## Currently faking it like this (which is what happens in covscan_handle_message):
    @covscan_run.update_attributes(:external_status => 'PASSED', :status => 'PASSED')

    # Should have updated the status (and now tests are passed)
    # (See also test/unit/external_test_type_test.rb)
    assert_equal 'PASSED', @covscan_run.status
    assert @errata.all_external_test_runs_passed?
  end

  test "unexpected covscan response raises error" do
    expected = {'status' => 'NOBEER', 'message' => 'No beer in the fridge.'}
    XMLRPC::CovscanClient.any_instance.expects(:get_scan_state).returns(expected)

    e = assert_raises(RuntimeError) do
      CovscanCreateObserver.update_covscan_test_run_state(@test_run)
    end
    assert e.message.include? expected['status']
    assert e.message.include? expected['message']
  end

  test "covscan error status raises CovscanError" do
    expected = {'status' => 'ERROR', 'message' => 'Test run not available'}
    XMLRPC::CovscanClient.any_instance.expects(:get_scan_state).returns(expected)

    assert_raises(CovscanError) do
      CovscanCreateObserver.update_covscan_test_run_state(@test_run)
    end
  end

end


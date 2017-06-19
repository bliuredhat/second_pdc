require 'test_helper'

class ExternalTestTypeTest < ActiveSupport::TestCase
  fixtures :external_test_types

  def setup
    # Create a external test type
    @foo_test_type = ExternalTestType.create!({
      :name          => 'foo',
      :display_name  => 'Foo Scan',
      :prod_run_url  => 'http://foo.redhat.com/scan/$ID/',
      :test_run_url  => 'http://foo-test.redhat.com/scan/$ID/',
      :info_url      => 'https://engineering.redhat.com/trac/AboutFoo/wiki',
    })

    # Grab an errata for testing
    @errata = rhba_async

    # Doesn't initially require foo test
    refute @errata.requires_external_test?(:foo)

    # Add foo test to state machine rule set
    @errata.state_machine_rule_set.test_requirements << 'foo'
    @errata.state_machine_rule_set.save!

    # Now it does require foo test
    assert @errata.reload.requires_external_test?(:foo)

    # Now we can create some external test runs
    @test_run_1 = @errata.create_external_test_run_for(:foo, :external_id=>456)
    @test_run_2 = @errata.create_external_test_run_for(:foo, :external_id=>789)
  end

  test "basic external test behaviours" do
    # Get is a utility for finding test types
    assert_equal ExternalTestType.get(:foo), @foo_test_type
    assert_equal ExternalTestType.get('foo'), @foo_test_type
    assert_equal ExternalTestType.get(@foo_test_type), @foo_test_type
    assert_equal ExternalTestType.find_by_name('foo'), @foo_test_type

    # Misc sanity tests
    assert_equal 'Foo', @foo_test_type.tab_name
    assert_equal 'Foo Scan', @foo_test_type.display_name

    # Runs created okay?
    assert_equal 2, @errata.external_test_runs_for(:foo).count
    assert_equal 2, @errata.current_external_test_runs_for(:foo).count

    # External links okay?
    assert_equal 'http://foo-test.redhat.com/scan/456/', @test_run_1.run_url
    assert_equal 'http://foo-test.redhat.com/scan/789/', @test_run_2.run_url

    # We have unpassed runs, so this should be false
    refute @errata.external_test_runs_passed_for?(:foo)

    # If we make the test run not 'current' should reduce current_external_test_runs
    # count but not the external_test_runs count
    assert_equal 2, @errata.external_test_runs_for(:foo).count
    assert_equal 2, @errata.current_external_test_runs_for(:foo).count
    @test_run_1.make_inactive!
    assert_equal 2, @errata.external_test_runs_for(:foo).count
    assert_equal 1, @errata.current_external_test_runs_for(:foo).count

    # A status of PASSED or WAIVED will count as passed
    @test_run_2.update_attribute(:status, 'PASSED')
    # Now all current runs are passed
    assert @errata.external_test_runs_passed_for?(:foo)

    # But if the inactive one becomes active again
    @test_run_1.make_active!
    # No longer all passed
    refute @errata.external_test_runs_passed_for?(:foo)

    # Let's waive it
    @test_run_1.update_attribute(:status, 'WAIVED')
    # Now all are passed
    assert @errata.external_test_runs_passed_for?(:foo)
  end

  test 'url can substitute $ERRATA_ID' do
    @foo_test_type.update_attributes(
      :test_run_url => 'http://example.com/$ERRATA_ID/$ID/foo')

    assert_equal("http://example.com/#{@errata.id}/456/foo",
                 @test_run_1.reload.run_url)
  end

  test 'url appends id if not present in template' do
    @foo_test_type.update_attributes(
      :test_run_url => 'http://example.com/test/')

    assert_equal("http://example.com/test/456",
                 @test_run_1.reload.run_url)
  end

  test "external test blocking transition guard" do
    # To block we need to add a transition guard.
    # Add it to the state_machine_rule_set for the test erratum.
    StateTransitionGuard.create_guard_helper(ExternalTestsGuard, @errata.state_machine_rule_set)

    # Set the guard to depend on our test type
    guard = @errata.state_machine_rule_set.state_transition_guards.where(:type => ExternalTestsGuard).first
    guard.external_test_types << @foo_test_type

    # Fudge so the rpmdiff transition guards doesn't get in the way.
    # (It's not ideal that this test is dependent on the specifics of
    # the rule set, but we should be able to get away with it for now).
    @errata.stubs(:rpmdiff_finished?).returns(true)

    # Ensure transition guard does it's thing
    assert_equal 'NEW_FILES', @errata.status
    assert_raise(ActiveRecord::RecordInvalid) { @errata.change_state!('QE', devel_user) }
    assert_equal 'NEW_FILES', @errata.status

    # Make all the tests passed
    @test_run_1.update_attribute(:status,'PASSED')
    @test_run_2.update_attribute(:status,'PASSED')

    # Now should transition okay
    @errata.change_state!('QE', devel_user)
    assert_equal 'QE', @errata.status
  end

  test 'handling of related types' do
    # We already have a 'foo' type, let's create a couple of subtypes
    (subtype1, subtype2) = create_subtypes

    # Any of these subtypes are considered applicable to the errata.
    assert @errata.requires_external_test?(:foo)
    assert @errata.requires_external_test?('foo/bar')
    assert @errata.requires_external_test?('foo/baz')

    # (not a made up type though...)
    refute @errata.requires_external_test?('foo/quux')

    # The errata currently has some foo test runs and not any other type...
    runs = @errata.external_test_runs_for('foo')
    assert_equal 2, runs.length

    assert @errata.external_test_runs_for('foo/bar').empty?
    assert @errata.external_test_runs_for('foo/baz').empty?

    # At this point, it is not considered passed
    refute @errata.external_test_runs_passed_for?('foo')

    # All subtypes are counted as "blocking"
    assert_equal(
      %w[foo foo/bar foo/baz],
      @errata.external_tests_blocking.map(&:name).grep(/foo/).sort)

    # If any one of the subtypes passes...
    bar_run = @errata.create_external_test_run_for('foo/bar', :external_id=>999)
    bar_run.status = 'PASSED'
    bar_run.save!

    # ... currently they're not yet counted as passed because the 'foo' test
    # runs are still active
    refute @errata.external_test_runs_passed_for?('foo')
    refute @errata.external_test_runs_passed_for?('foo/bar')
    refute @errata.external_test_runs_passed_for?('foo/baz')

    # If the only active test is a passed test of a subtype, all subtypes are
    # considered passed
    [@test_run_1, @test_run_2].each do |run|
      run.update_attributes(:active => 0)
    end
    assert @errata.external_test_runs_passed_for?('foo')
    assert @errata.external_test_runs_passed_for?('foo/bar')
    assert @errata.external_test_runs_passed_for?('foo/baz')

    assert_equal([], @errata.external_tests_blocking.map(&:name).grep(/foo/))

    # Unlike the above methods which process all related types together,
    # external_test_runs_for still deals with the explicitly passed type only
    assert_equal(
      [@test_run_1, @test_run_2],
      @errata.external_test_runs_for('foo').order('id asc'))

    assert_equal(
      [bar_run],
      @errata.external_test_runs_for('foo/bar'))

    assert_equal(
      [],
      @errata.external_test_runs_for('foo/baz'))
  end

  test 'with_related_types methods' do
    (subtype1, subtype2) = create_subtypes

    expected = [@foo_test_type, subtype1, subtype2]

    assert_equal expected, @foo_test_type.with_related_types.order('id asc')
    assert_equal expected, subtype1.with_related_types.order('id asc')

    # it works on relations as well
    assert_equal expected, ExternalTestType.
                           where(:id => @foo_test_type).
                           with_related_types.
                           order('id asc')

    assert_equal expected, ExternalTestType.
                           where(:id => [subtype1, subtype2]).
                           with_related_types.
                           order('id asc')
  end

  def create_subtypes
    subtype1 = ExternalTestType.create!(
      :name          => 'foo/bar',
      :display_name  => 'Foo Scan (bar)',
      :prod_run_url  => 'http://foo.redhat.com/scan/$ID/',
      :test_run_url  => 'http://foo-test.redhat.com/scan/$ID/',
      :info_url      => 'https://engineering.redhat.com/trac/AboutFoo/wiki')

    subtype2 = ExternalTestType.create!(
      :name          => 'foo/baz',
      :display_name  => 'Foo Scan (baz)',
      :prod_run_url  => 'http://foo.redhat.com/scan/$ID/',
      :test_run_url  => 'http://foo-test.redhat.com/scan/$ID/',
      :info_url      => 'https://engineering.redhat.com/trac/AboutFoo/wiki')

    [subtype1, subtype2]
  end
end

require 'test_helper'

class RpmdiffRunsInvalidationTest < ActiveSupport::TestCase

  # This testdata describes a sequence of rpmdiff runs with their score, along with
  # the expected full history (in text form) after the run completes.
  # This tests the logic relating to old_version/new_version and run invalidation.
  RPMDIFF_RUN_SEQUENCE = [
      ['1:gcc-4.0.0-1.el6', RpmdiffScore::FAILED, <<-'eos'.strip_heredoc.chomp],
        gcc - NEW_PACKAGE => 4.0.0-1.el6: Failed
        eos

      ['1:gcc-4.0.0-2.el6', RpmdiffScore::FAILED, <<-'eos'.strip_heredoc.chomp],
        gcc - NEW_PACKAGE => 4.0.0-1.el6: Failed (OBSOLETE)
        gcc - NEW_PACKAGE => 4.0.0-2.el6: Failed
        eos

      ['1:gcc-4.0.1-1.el6', RpmdiffScore::INFO, <<-'eos'.strip_heredoc.chomp],
        gcc - NEW_PACKAGE => 4.0.0-1.el6: Failed (OBSOLETE)
        gcc - NEW_PACKAGE => 4.0.0-2.el6: Failed (OBSOLETE)
        gcc - NEW_PACKAGE => 4.0.1-1.el6: Info
        eos

      ['1:gcc-4.0.1-2.el6', RpmdiffScore::WAIVED, <<-'eos'.strip_heredoc.chomp],
        gcc - NEW_PACKAGE => 4.0.0-1.el6: Failed (OBSOLETE)
        gcc - NEW_PACKAGE => 4.0.0-2.el6: Failed (OBSOLETE)
        gcc - NEW_PACKAGE => 4.0.1-1.el6: Info
        gcc - 4.0.1-1.el6 => 4.0.1-2.el6: Waived
        eos

      ['1:gcc-4.1.2-1.el6', RpmdiffScore::NEEDS_INSPECTION, <<-'eos'.strip_heredoc.chomp],
        gcc - NEW_PACKAGE => 4.0.0-1.el6: Failed (OBSOLETE)
        gcc - NEW_PACKAGE => 4.0.0-2.el6: Failed (OBSOLETE)
        gcc - NEW_PACKAGE => 4.0.1-1.el6: Info
        gcc - 4.0.1-1.el6 => 4.0.1-2.el6: Waived
        gcc - 4.0.1-2.el6 => 4.1.2-1.el6: Needs inspection
        eos

      ['1:gcc-4.1.7-1.el6', RpmdiffScore::PASSED, <<-'eos'.strip_heredoc.chomp],
        gcc - NEW_PACKAGE => 4.0.0-1.el6: Failed (OBSOLETE)
        gcc - NEW_PACKAGE => 4.0.0-2.el6: Failed (OBSOLETE)
        gcc - 4.0.1-2.el6 => 4.1.2-1.el6: Needs inspection (OBSOLETE)
        gcc - NEW_PACKAGE => 4.0.1-1.el6: Info
        gcc - 4.0.1-1.el6 => 4.0.1-2.el6: Waived
        gcc - 4.0.1-2.el6 => 4.1.7-1.el6: Passed
        eos

      ['1:gcc-4.1.7-3.el6', RpmdiffScore::FAILED, <<-'eos'.strip_heredoc.chomp],
        gcc - NEW_PACKAGE => 4.0.0-1.el6: Failed (OBSOLETE)
        gcc - NEW_PACKAGE => 4.0.0-2.el6: Failed (OBSOLETE)
        gcc - 4.0.1-2.el6 => 4.1.2-1.el6: Needs inspection (OBSOLETE)
        gcc - NEW_PACKAGE => 4.0.1-1.el6: Info
        gcc - 4.0.1-1.el6 => 4.0.1-2.el6: Waived
        gcc - 4.0.1-2.el6 => 4.1.7-1.el6: Passed
        gcc - 4.1.7-1.el6 => 4.1.7-3.el6: Failed
        eos

      ['1:gcc-4.2.0-1.el6', RpmdiffScore::PASSED, <<-'eos'.strip_heredoc.chomp],
        gcc - NEW_PACKAGE => 4.0.0-1.el6: Failed (OBSOLETE)
        gcc - NEW_PACKAGE => 4.0.0-2.el6: Failed (OBSOLETE)
        gcc - 4.0.1-2.el6 => 4.1.2-1.el6: Needs inspection (OBSOLETE)
        gcc - 4.1.7-1.el6 => 4.1.7-3.el6: Failed (OBSOLETE)
        gcc - NEW_PACKAGE => 4.0.1-1.el6: Info
        gcc - 4.0.1-1.el6 => 4.0.1-2.el6: Waived
        gcc - 4.0.1-2.el6 => 4.1.7-1.el6: Passed
        gcc - 4.1.7-1.el6 => 4.2.0-1.el6: Passed
        eos

      ['2:gcc-1.201401-1.el6', RpmdiffScore::FAILED, <<-'eos'.strip_heredoc.chomp],
        gcc - NEW_PACKAGE => 4.0.0-1.el6: Failed (OBSOLETE)
        gcc - NEW_PACKAGE => 4.0.0-2.el6: Failed (OBSOLETE)
        gcc - 4.0.1-2.el6 => 4.1.2-1.el6: Needs inspection (OBSOLETE)
        gcc - 4.1.7-1.el6 => 4.1.7-3.el6: Failed (OBSOLETE)
        gcc - NEW_PACKAGE => 4.0.1-1.el6: Info
        gcc - 4.0.1-1.el6 => 4.0.1-2.el6: Waived
        gcc - 4.0.1-2.el6 => 4.1.7-1.el6: Passed
        gcc - 4.1.7-1.el6 => 4.2.0-1.el6: Passed
        gcc - 4.2.0-1.el6 => 1.201401-1.el6: Failed
        eos

      ['2:gcc-1.201402-1.el6', RpmdiffScore::PASSED, <<-'eos'.strip_heredoc.chomp],
        gcc - NEW_PACKAGE => 4.0.0-1.el6: Failed (OBSOLETE)
        gcc - NEW_PACKAGE => 4.0.0-2.el6: Failed (OBSOLETE)
        gcc - 4.0.1-2.el6 => 4.1.2-1.el6: Needs inspection (OBSOLETE)
        gcc - 4.1.7-1.el6 => 4.1.7-3.el6: Failed (OBSOLETE)
        gcc - 4.2.0-1.el6 => 1.201401-1.el6: Failed (OBSOLETE)
        gcc - NEW_PACKAGE => 4.0.1-1.el6: Info
        gcc - 4.0.1-1.el6 => 4.0.1-2.el6: Waived
        gcc - 4.0.1-2.el6 => 4.1.7-1.el6: Passed
        gcc - 4.1.7-1.el6 => 4.2.0-1.el6: Passed
        gcc - 4.2.0-1.el6 => 1.201402-1.el6: Passed
        eos
  ]

  # make one testfunction for each step so that we keep going and output all failure
  # diffs even if something goes wrong on an early step
  RPMDIFF_RUN_SEQUENCE.each_index do |i|
    test "rpmdiff run invalidation - step #{i}" do
      do_invalidation_test(i)
    end
  end

  test 'invalidation is no-op when builds are not changed' do
    e = RHBA.find(10808)
    run_count = e.rpmdiff_runs.current.count
    assert run_count > 0, 'fixture problem: advisory must have some current rpmdiff runs'

    RpmdiffRun.invalidate_obsolete_runs(e)

    assert_equal run_count, e.rpmdiff_runs.current.count, 'some runs were unexpectedly invalidated'
  end

  test 'all runs are invalidated if all builds are removed' do
    e = RHBA.find(10808)
    assert e.rpmdiff_runs.current.any?, 'fixture problem: advisory must have some current rpmdiff runs'

    e.stubs(:brew_builds => BrewBuild.where('1=0'))
    RpmdiffRun.invalidate_obsolete_runs(e)

    refute e.rpmdiff_runs.current.any?, 'removing all brew builds failed to invalidate all rpmdiff runs'
  end

  def add_fake_brew_build(e, nvr)
    # here we permit epoch in nvr: epoch:name-version-release

    arch = Arch.find_by_name('x86_64')
    src_arch = Arch.SRPM

    (epoch, rest) = nvr.split(':', 2)
    (name, version, release) = rest.split('-', 3)
    package = Package.find_by_name(name)
    build = BrewBuild.create!(
      :package => package,
      :version => version,
      :release => release,
      :epoch => epoch,
      :nvr => nvr
    )
    [arch,src_arch].each do |a|
      BrewRpm.create!(
        :id_brew => BrewRpm.pluck('max(id_brew)').first + 100,
        :brew_build => build,
        :package => package,
        :epoch => epoch.to_i,
        :arch => a,
        :name => nvr
      )
    end
    ErrataBrewMapping.create!(:errata => e, :brew_build => build, :product_version => e.available_product_versions.first, :package => package)
  end

  def do_invalidation_test(step)
    e = Errata.find(11152)
    gcc = Package.find_by_name('gcc')

    e.rpmdiff_runs.map(&:rpmdiff_results).each(&:destroy_all)
    e.rpmdiff_runs.destroy_all

    variant = e.available_product_versions.first.variants.first

    i = 0
    RPMDIFF_RUN_SEQUENCE.each do |nvr,score,expected_history|
      ActiveRecord::Base.transaction do
        e.build_mappings.each(&:obsolete!)
        mapping = add_fake_brew_build(e, nvr)
        e.reload

        RpmdiffRun.create!(
          :errata => e,
          :package => gcc,
          :brew_build => mapping.brew_build,
          :errata_brew_mapping => mapping,
          :variant => variant
        ).tap{|rr| rr.update_attribute(:overall_score, score)}
      end

      if i == step
        actual_history = dump_rpmdiff_runs(e).join("\n")
        assert_equal_or_diff expected_history, actual_history, "History after rpmdiff run for #{nvr} looks wrong"
      end

      i+=1
    end
  end

  # formats rpmdiff runs into a simple plaintext format for nice test assertions/diffs
  def dump_rpmdiff_runs(e)
    e.reload
    e.rpmdiff_runs.sort_by{|rr| [rr.obsolete? ? 0 : 1, rr.id]}.map do |rr|
      score = RpmdiffScore.find(rr.overall_score).description
      "#{rr.package.name} - #{rr.old_version} => #{rr.new_version}: #{score}#{rr.obsolete? ? ' (OBSOLETE)' : ''}"
    end
  end
end

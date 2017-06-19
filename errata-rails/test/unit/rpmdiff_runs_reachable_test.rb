require 'test_helper'

class RpmdiffRunsReachableTest < ActiveSupport::TestCase
  def make_run(opts)
    pkg = Package.find_by_name(opts[:package])
    e = opts[:errata]

    (version,release) = opts[:new_version].split('-', 2)

    nvr = "#{pkg.name}-#{version}-#{release}"
    brew_build = BrewBuild.find_by_nvr(nvr)
    if brew_build.nil?
      brew_build = BrewBuild.create!(
        :package_id => pkg.id,
        :version => version,
        :release => release,
        :nvr => nvr
      )
    end

    RpmdiffRun.connection.insert_fixture({
        :errata_id => e.id,
        :package_name => pkg.name,
        :package_id => pkg.id,
        :old_version => opts[:old_version],
        :new_version => opts[:new_version],
        :run_date => Time.now,
        :overall_score => 0,
        :person => User.current_user.login_name,
        :obsolete => opts[:obsolete] ? 1 : 0,
        :variant => e.available_product_versions.first.variants.first.id,
        :brew_build_id => brew_build.id
      },
      'rpmdiff_runs'
    )
    RpmdiffRun.last
  end

  def make_errata_with_runs(rundata)
    e = Errata.qe.find{|errata| errata.available_product_versions.any?}
    e.rpmdiff_runs.map(&:rpmdiff_results).each(&:destroy_all)
    e.rpmdiff_runs.destroy_all

    current_builds = []
    rundata.in_groups_of(4).each do |pkg,old_nvr,new_nvr,opts|
      opts = if opts == '-'
        {}
      else
        opts.split(',').inject({}) {|hsh,key| hsh[key.to_sym] = true; hsh }
      end

      run = make_run(
        opts.merge(:errata => e, :package => pkg, :old_version => old_nvr, :new_version => new_nvr)
      )
      if opts[:with_brew_build]
        current_builds << run.brew_build
      end
    end

    e.reload
    e.stubs(:brew_builds => current_builds)
    e
  end

  def do_reachable_test(all_runs, expected_reachable_runs)
    e = make_errata_with_runs all_runs
    got = RpmdiffRun.reachable_runs(e).sort_by(&:id).map{|r| [r.package.name, r.old_version, r.new_version]}
    expected = expected_reachable_runs.in_groups_of(3)

    assert_array_equal expected, got
  end

  test 'none reachable when no brew builds' do
    do_reachable_test(
      %w{
        gcc NEW_PACKAGE 1.2.3-1 -
        gcc 1.2.3-1     1.2.4-1 -
      },
      %w{}
    )
  end

  test 'run with a brew build is reachable' do
    do_reachable_test(
      %w{gcc NEW_PACKAGE 1.2.3-1 with_brew_build},
      %w{gcc NEW_PACKAGE 1.2.3-1}
    )
  end

  test 'run one level away from a brew build is reachable' do
    do_reachable_test(
      %w{
        gcc NEW_PACKAGE 1.2.3-1 -
        gcc 1.2.3-1     1.2.4-1 with_brew_build
      },
      %w{
        gcc NEW_PACKAGE 1.2.3-1
        gcc 1.2.3-1     1.2.4-1
      }
    )
  end

  test 'run two levels away from a brew build is reachable' do
    do_reachable_test(
      %w{
        gcc NEW_PACKAGE 1.2.3-1 -
        gcc 1.2.3-1     1.2.3-2 -
        gcc 1.2.3-2     1.2.3-3 with_brew_build
      },
      %w{
        gcc NEW_PACKAGE 1.2.3-1
        gcc 1.2.3-1     1.2.3-2
        gcc 1.2.3-2     1.2.3-3
      }
    )
  end

  # scenario: while a minor release is being prepared for a package,
  # a patch release is shipped, changing the baseline.
  # Only runs from the new baseline are reachable, even if the build wasn't
  # redone with a newer nvr after baseline change.
  test 'runs before a baseline change are not reachable' do
    do_reachable_test(
      %w{
        gcc 1.1.0-1.el6 1.2.0-1.el6 -
        gcc 1.2.0-1.el6 1.2.0-2.el6 -

        gcc 1.1.1-1.el6 1.2.0-2.el6 -
        gcc 1.2.0-2.el6 1.2.0-3.el6 with_brew_build
      },
      %w{
        gcc 1.1.1-1.el6 1.2.0-2.el6
        gcc 1.2.0-2.el6 1.2.0-3.el6
      }
    )
  end

  # shouldn't happen in production as far as I know
  test 'newer versions without brew build are not reachable' do
    do_reachable_test(
      %w{
        gcc NEW_PACKAGE 1.2.3-1 -
        gcc 1.2.3-1     1.2.3-2 with_brew_build
        gcc 1.2.3-2     1.2.3-3 -
      },
      %w{
        gcc NEW_PACKAGE 1.2.3-1
        gcc 1.2.3-1     1.2.3-2
      }
    )
  end

  test 'run with an unreachable new_version is not reachable' do
    do_reachable_test(
      %w{
        gcc NEW_PACKAGE 1.2.3-1 -
        gcc 1.2.3-1     1.2.3-2 -
        gcc 1.2.3-1     1.2.3-3 with_brew_build
      },
      %w{
        gcc NEW_PACKAGE 1.2.3-1
        gcc 1.2.3-1     1.2.3-3
      }
    )
  end

  test 'obsolete runs are not reachable' do
    do_reachable_test(
      %w{
        gcc 1.2.3-1     1.2.3-2 obsolete
        gcc 1.2.3-2     1.2.3-3 with_brew_build
      },
      %w{
        gcc 1.2.3-2     1.2.3-3
      }
    )
  end

  # could occur if a run was explicitly marked obsolete
  test 'history traversal stops at obsolete runs' do
    do_reachable_test(
      %w{
        gcc NEW_PACKAGE 1.2.3-1 -
        gcc 1.2.3-1     1.2.3-2 obsolete
        gcc 1.2.3-2     1.2.3-3 with_brew_build
      },
      %w{
        gcc 1.2.3-2     1.2.3-3
      }
    )
  end

  test 'no confusion from interleaved versions between packages' do
    do_reachable_test(
      %w{
        gcc NEW_PACKAGE 1-1 -
        gdb 1-1         1-2 -
        gcc 1-2         1-3 -
        gdb 1-3         1-4 with_brew_build
      },
      %w{
        gdb 1-3         1-4
      }
    )
  end

  test 'no confusion from duplicate versions between packages' do
    do_reachable_test(
      %w{
        gcc NEW_PACKAGE 1-1 -
        gdb NEW_PACKAGE 1-1 -
        gcc 1-1         1-2 -
        gdb 1-1         1-2 -
        gcc 1-2         1-3 -
        gdb 1-2         1-3 with_brew_build
      },
      %w{
        gdb NEW_PACKAGE 1-1
        gdb 1-1         1-2
        gdb 1-2         1-3
      }
    )
  end
end

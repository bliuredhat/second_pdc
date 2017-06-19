namespace :fix_builds_missing_files do
  def print_build(build, old_files, added_files)
    puts [
      build.id,
      "#{old_files.count}->#{build.brew_files.count}",
      added_files.map(&:filename).sort.join(',').truncate(80),
    ].join("\t")
  end

  # Try to do something, retrying a few times, eventually continuing
  # if the block repeatedly raises.
  def tolerating_errors(label, attempts=3)
    attempt=0
    begin
      attempt = attempt + 1
      return yield
    rescue => e
      $stderr.puts "#{label} failed: #{e} [#{attempt} / #{attempts}]"
      retry if attempt < attempts
    end
  end

  # Given a collection of builds, imports any missing RPMs from Brew.
  # Yields fixed builds with the added file objects.
  def fix_builds(builds)
    builds.each do |build|
      tolerating_errors("Build #{build.id}") do
        old_files = build.brew_files.pluck('id')

        # This could also be import_files_from_rpc, which would include non-RPM
        # files.  However, that requires twice the number of RPC calls and there
        # are no known cases of missing non-RPM files, so don't bother.
        build.import_rpms_from_rpc

        # note no `save' necessary when creating objects through a relationship
        added_files = build.reload.brew_files.where('id not in (?)', old_files)

        if added_files.present?
          yield(build, old_files, added_files)
        end
      end
    end
  end

  # Do something in a transaction. Roll it back unless really is true.
  def commit_if(really)
    out = nil
    ActiveRecord::Base.transaction do
      out = yield
      raise ActiveRecord::Rollback unless really
    end
    out
  end

  desc "Find (and possibly re-fetch) Brew builds with missing files"
  task :run => :environment do
    # Only Brew builds with a release like this are checked.
    # For bug 1245659, specifically aarch64/ppc64le files are of interest,
    # and these have only been built for RHEL7.
    release_like = ENV['RELEASE_LIKE'] || '%el7%'

    # Brew builds >= this ID are checked.
    # The default is from about March 2013, that's the earliest I've found
    # with missing ppc64le/aarch64 files from a recent DB snapshot.
    from_id = ENV.fetch('FROM_ID', 260000).to_i

    # Only actually save the modifications if REALLY=1
    really = ENV['REALLY'] == '1'

    # Comment text added to any affected errata.
    comment = ENV['COMMENT'] || <<'eos'
Missing aarch64/ppc64le files have been imported to Brew builds associated with
this advisory.  These files will not be added to the file list of this advisory
until the "Reload files" action is triggered.

If this advisory is expected to ship ppc64le/aarch64 content, consider
using the "Reload files" action now.

For more information, see: http://bugzilla.redhat.com/1245659
eos

    builds = BrewBuild.
      where('id >= ?', from_id).
      where('`release` like ?', release_like)

    # Separate builds into those currently on unshipped errata, and
    # those not.  All of them should be fixed, but the ones on
    # unshipped errata are more important.
    active_ebm = ErrataBrewMapping.current.where(:errata_id => Errata.active)
    active_builds = builds.where(:id => active_ebm.select('brew_build_id'))
    inactive_builds = builds.where('id not in (?)', active_builds.select('id'))

    puts "CHECKING BUILDS: %d active, %d inactive" %
      [active_builds.count, inactive_builds.count]

    unless really
      puts "(Not really going to modify anything. Set REALLY=1 if you want to.)"
    end

    # Using separate transactions so that e.g. the task can be
    # interrupted while handling inactive builds without losing the
    # progress from the active builds.
    fixed_active_build_ids = []
    commit_if(really) do
      puts "\nFIXED ACTIVE BUILDS:"
      fix_builds(active_builds) do |build, old_files, added_files|
        print_build(build, old_files, added_files)
        fixed_active_build_ids << build.id
      end

      puts "\nAFFECTED ERRATA:"
      active_ebm.
        where(:brew_build_id => fixed_active_build_ids).
        map(&:errata).
        each do |errata|
          errata.comments.create!(:who => User.system, :text => comment)
          puts "#{errata.id}\t#{errata.advisory_name}\t#{errata.status}"
        end
    end

    commit_if(really) do
      puts "\nFIXED INACTIVE BUILDS:"
      fix_builds(inactive_builds, &method(:print_build))
    end
  end
end

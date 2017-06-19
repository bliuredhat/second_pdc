#
#
# The way we do the bug syncing doesn't always recover well when Bugzilla times out
# or is unavailable and hence sometimes bugs get out of sync with Bugzilla.
#
# This prevents the bugs from being added to advisories and hence can be a critical
# problem.
#
# These scripts are for recovering from the situation by doing a big brute force
# sync of all the bugs.
#
# Inspired by this ticket:
#   https://engineering.redhat.com/rt/Ticket/Display.html?id=177251
#
# See also debug_xmlrpc.rake
# (Todo: move non-debug stuff out of there and into here...)
#
# See also:
#   lib/bugzilla/update_filed_bugs_job.rb
#
namespace :bugs do
  namespace :reconcile do
    CHUNK_SIZE = 32

    def is_dry_run?
      ENV['REALLY'] != 'YES'
    end

    def dry_run_message
      puts "Rails.env: #{Rails.env}, BUGZILLA_SERVER: #{Bugzilla::BUGZILLA_SERVER}"
      puts "Dry run mode. Add REALLY=YES on command line to really sync bugs." if is_dry_run?
    end

    def do_bug_sync_now(bugs)
      num_chunks = (bugs.count.to_f / CHUNK_SIZE).ceil
      puts "About to syncronise #{bugs.count} bugs (in #{num_chunks} groups of #{CHUNK_SIZE})."
      dry_run_message
      ask_to_continue_or_cancel

      # Prepare xml rpc client
      bugzilla = Bugzilla::Rpc.get_connection unless is_dry_run?

      # Chunk up the bug ids
      bugs.map(&:id).each_slice(CHUNK_SIZE).each_with_index do |bug_ids_chunked, i|
        # Show progress...
        puts "Syncing bugs #{i+1}/#{num_chunks} (#{bug_ids_chunked.first}..#{bug_ids_chunked.last})"

        unless is_dry_run?
          # Do sync (calls xmlrpc, updates bugs)
          bugzilla.reconcile_bugs(bug_ids_chunked)

          # Give Bugzilla a breather
          sleep(2)
        end
      end
    end

    desc "Reconcile unfiled bugs in NEW and ASSIGNED"
    task :unfiled => :environment do
      # Not sure if this is always suitable, but go with it for now.
      # Trying to limit how many needless syncs we do.
      # (Presume if it is MODIFIED they can already add it)
      STATUSES = %w[NEW ASSIGNED]

      # Hack this sql as required...
      bugs = Bug.find_by_sql %{
        SELECT
          bugs.id
        FROM
          bugs
          -- Left (outer) join because we want to know which bugs
          -- are not filed yet
          LEFT JOIN filed_bugs ON bugs.id = filed_bugs.bug_id
        WHERE
          -- Hence not yet filed..
          filed_bugs.bug_id IS NULL
        AND
          bugs.bug_status in (#{STATUSES.map { |s| "'#{s}'" }.join(', ')})
        -- AND
          -- some other condition?
        ORDER BY
          -- Let's do newest first
          id DESC
      }

      do_bug_sync_now(bugs)
    end

    desc "Reconcile bugs in all active advisories"
    task :active_advisories => :environment do
      bugs = Errata.active.map(&:bugs).flatten.sort_by(&:id)
      do_bug_sync_now(bugs)
    end

    # This one is a bit different. It doesn't use do_bug_sync_now.
    desc "Update bugs since N hours ago"
    task :bugs_since => :environment do
      n = ENV['HOURS'].try(:to_i) || 1
      rpc_bugs = Bugzilla::Rpc.new.bugs_changed_since(n.hours.ago)
      puts "Found #{rpc_bugs.length} updated since #{n} hours ago"
      dry_run_message
      unless is_dry_run?
        rpc_bugs.each do |rpc_bug|
          puts "Creating or updating bug #{rpc_bug.bug_id}"
          Bug.make_from_rpc(rpc_bug)
        end
      end
    end

  end
end


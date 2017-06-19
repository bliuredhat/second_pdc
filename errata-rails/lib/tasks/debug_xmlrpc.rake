namespace :debug do
  namespace :xmlrpc do
    namespace :bugzilla do

      # TODO: Don't really need this host list now since we could just use the ET_DEV_RPC_BUGZILLA_SERVER
      # environment variable, (see config/intializers/credentials/bugzilla). The valid_cert option is no
      # longer needed either, (see HOSTS_WITH_GOOD_CERTS in lib/bugzilla/rpc).
      BZ_SERVERS = {
        :prod    => { :host => 'bugzilla.redhat.com', :valid_cert => true },
        :partner => { :host => 'partner-bugzilla.redhat.com', :valid_cert => true }, # currently running bz 4.2 for test purposes
        :test    => { :host => 'rt115595.bz-devel.eng.bne.redhat.com', :valid_cert => false }, # sgreen's test server, as at 8-Jul-2011
        :newauth => { :host => 'bzweb01-devel.app.eng.rdu.redhat.com', :valid_cert => false }, # to test new auth mechanism, 22-Apr-2014
      }

      # Change this depending on what you want to test against...
      BZ_SERVER = BZ_SERVERS[:partner]

      def get_bugzilla_service
        # This would use everything as per config/intializers/credentials/bugzilla
        #Bugzilla::Rpc.get_connection

        # Uses the server specified (but credentials from config/intializers/credentials/bugzilla)
        puts "Using server: #{BZ_SERVER[:host]}"
        Bugzilla::Rpc.new(BZ_SERVER[:host], BZ_SERVER[:valid_cert])
      end

      #--------------------------------------------------------------------------------
      # Was using these to test changes to Bz 4.2 API, see bug 820790
      # Should hit the partner-bugzilla bugzilla host, not production.
      # Has some hard coded bug ids etc, so be careful and take a look at what's happening
      # before running these scripts.

      desc "get a bug and show it"
      task :show_bug => :environment do
        bug_id = ENV['BUG_ID'] or raise "You must specify a bug id"
        rpc_bug = get_bugzilla_service.get_bugs([bug_id.to_i]).first

        # Mainly want to test this with and without Settings.bugzilla_42_mode set...
        puts [
          BZ_SERVER[:host],
          Bugzilla::Rpc::INCLUDE_FIELDS.inspect,
          rpc_bug.inspect,
          "rpc_bug.flags: #{rpc_bug.flags.inspect}",
        ].join("\n\n")
      end

      # See bug 1089848
      desc "test token style auth"
      task :test_token_auth => :environment do
        BZ_SERVER = BZ_SERVERS[:newauth]
        bz = get_bugzilla_service
        bug_id = '838158' # NB: use a private bug because a public bug will work regardless
        bug_id = ENV['BUG_ID'] if ENV['BUG_ID'].present?
        # If we can't login this will fail with a "You are not authorized.." message
        resp = bz.get_bugs([bug_id.to_i])
        bug = resp.first
        puts "#{bug.bug_id} - #{bug.summary}"
      end

      desc "test bugs_changed_since"
      task :changed_since => :environment do
        # Doing this a bit differently. Overwrite the constant!
        # (Instead of using get_bugzilla_service...)
        Bugzilla::BUGZILLA_SERVER = BZ_SERVER[:host]
        puts BZ_SERVER[:host]

        since_when = 10.hours.ago
        puts since_when.inspect
        ids = Bugzilla::Rpc.new.bugs_changed_since(since_when)
        puts ids.inspect
      end

      desc "test changeStatus"
      task :change_status => :environment do
        bug_id = '725219'
        bug_id = ENV['BUG_ID'] if ENV['BUG_ID'].present?
        ask_to_continue_or_cancel("About to change status for #{bug_id} on #{Bugzilla::BUGZILLA_SERVER}. Okay?")
        resp = Bugzilla::Rpc.new.changeStatus(bug_id, 'MODIFIED', 'Test, please ignore.')
        puts resp.inspect
      end

      desc "test addComment"
      task :add_comment => :environment do
        bug_id = '725219'
        bug_id = ENV['BUG_ID'] if ENV['BUG_ID'].present?
        ask_to_continue_or_cancel("About to add a comment on #{bug_id} on #{Bugzilla::BUGZILLA_SERVER}. Okay?")
        resp = Bugzilla::Rpc.new.add_comment(bug_id, 'Test, please ignore.')
        puts resp.inspect
      end

      desc "desc closeBug"
      task :close_bug => :environment do
        # NB: You have to comment out the id Rails.env.production? in this line in rpc.rb to test this...
        # @proxy.closeBug(bug.bug_id, 'ERRATA', BUGZILLA_USER, BUGZILLA_PASSWORD, "", advisory, comment, 0) #if Rails.env.production?

        # (Always use partner, don't want to do this on production for obvious reasons...)
        Bugzilla::BUGZILLA_SERVER = BZ_SERVERS[:partner][:host]
        puts BZ_SERVERS[:partner][:host]

        bugzilla = Bugzilla::Rpc.new

        # Need to make the bug first (since closeBug is actually our local
        # wrapper method that does some stuff before calling the rpc method and
        # expects a Bug record to exist...)
        rpc_bug = bugzilla.get_bugs([725219]).first
        Bug.make_from_rpc(rpc_bug)

        # Try to close it. (Fudging the Errata record, hopefully that's okay).
        resp = bugzilla.closeBug(Bug.find(725219), Errata.last)
        puts resp.inspect
      end

      #--------------------------------------------------------------------------------
      # The following methods are for reconciling bugs rather than testing/debugging..

      #
      # Do a bug reconcile on a given bug id
      #
      # Usage:
      #   rake debug:xmlrpc:bugzilla:reconcile_bug BUG_ID=123123
      #
      # Handy command to copy/paste if you are already in the rails console:
      #
      #   Bugzilla::Rpc.get_connection.reconcile_bugs([123123])
      #
      desc "reconcile a given bug"
      task :reconcile_bug => :environment do
        bug_id = ENV['BUG_ID'] or raise "You must specify a bug id"
        bug = Bug.find(bug_id) or raise "Bug not found"

        bugzilla = Bugzilla::Rpc.get_connection

        puts "Before:\n#{bug.to_yaml}\n\n"
        bugzilla.reconcile_bugs([bug.id])
        puts "After:\n#{Bug.find(bug.id).to_yaml}\n\n"
      end

      desc "create a bug from rpc"
      task :create_bug => [:environment, :development_only] do
        bug_id = ENV['BUG_ID'] or raise "You must specify a bug id"
        bugzilla = Bugzilla::Rpc.get_connection
        rpc_bug = bugzilla.get_bugs([bug_id.to_i]).first
        Bug.make_from_rpc(rpc_bug) if rpc_bug
      end

      #
      # Does a bug reconcile on a given errata
      #
      desc "reconcile all bugs in a given errata"
      task :reconcile_errata_bugs => :environment do
        errata_id = ENV['ERRATA_ID'] or raise "You must specify an errata id"
        errata = Errata.find(errata_id) or raise "Errata not found"
        bugzilla = Bugzilla::Rpc.get_connection

        # This would work but I want to print out the before/after
        #bugzilla.reconcile_bugs(errata.bugs.map(&:id))

        errata.bugs.each do |bug|
          puts "Before:\n#{bug.to_yaml}\n\n"
          bugzilla.reconcile_bugs([bug.id])
          puts "After:\n#{Bug.find(bug.id).to_yaml}\n\n"
        end
      end

      #
      # Do a bug reconcile on all bugs in docs queue.
      #
      desc "reconcile all bugs in docs queue"
      task :reconcile_docs_queue => :environment do
        # See DocsController#errata_in_queue
        docs_queue = Errata.find(:all, :conditions => "
          is_valid = 1 AND
          status NOT IN ('SHIPPED_LIVE', 'DROPPED_NO_SHIP') AND
          text_ready = 1 AND
          doc_complete = 0
        ")

        bugzilla = Bugzilla::Rpc.get_connection
        docs_queue.each do |errata|
          puts "Reconciling bugs for errata #{errata.id}"
          bugzilla.reconcile_bugs(errata.bugs.map(&:id))
        end
      end

      # See https://engineering.redhat.com/rt/Ticket/Display.html?id=169835
      # and https://bugzilla.redhat.com/show_bug.cgi?id=867158
      desc "flag check"
      task :flag_check => :environment do
        flag = ENV['FLAG'] or raise "Must specify flag on command line, eg rake debug:xmlrpc:bugzilla:flag_check FLAG=on-premise-1.0.0"
        pp get_bugzilla_service.approved_components_for(flag)
      end

    end
  end
end

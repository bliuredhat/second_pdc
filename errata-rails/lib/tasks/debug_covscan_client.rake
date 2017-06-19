#
# Some tasks running/testing/debugging covscan xmlrpc calls.
#
# See lib/xmlrpc/covscan_client.
#
namespace :debug do
  namespace :covscan do

    desc "create scans for errata"
    task :create_scans_for_errata => :environment do
      FromEnvId.get_errata.errata_brew_mappings.each do |errata_brew_mapping|
        CovscanCreateObserver.create_covscan_run_maybe(errata_brew_mapping)
      end
    end

    desc "create scan for errata_brew_mapping"
    task :create_scan_for_mapping => :environment do
      CovscanCreateObserver.create_covscan_run_maybe(FromEnvId.get_mapping)
    end

    desc "reschedule test run"
    task :reschedule_test_run => :environment do
      FromEnvId.get_test_run.covscan_reschedule!
    end

    desc "refresh status for test run"
    task :refresh_test_run_status => :environment do
      CovscanCreateObserver.update_covscan_test_run_state(FromEnvId.get_test_run)
    end

    # Refreshes the state of all scans for an advisory.
    # Might be useful if qpid goes down and we need to re-sync many scan states.
    desc "refresh status for all errata's test runs"
    task :refresh_test_run_status_for_errata => :environment do
      FromEnvId.get_errata.external_test_runs_for(:covscan).each do |external_test_run|
        CovscanCreateObserver.update_covscan_test_run_state(external_test_run)
      end
    end

    namespace :api do
      def covscan_client(opts={})
        XMLRPC::CovscanClient.new(opts.reverse_merge(:debug=>true, :verbose=>false))
      end

      # This is readonly so it's safe to use whenever.
      desc "test covscan xmlrpc get_scan_state api call"
      task :scan_info => :environment do
        url = 'http://cov01.lab.eng.brq.redhat.com/covscanhub/xmlrpc/kerbauth/' if ENV['USE_PROD'] # set this if you want to try prod
        pp covscan_client(:url=>url).get_scan_state(ENV['ID'] || ExternalTestRun.of_type(:covscan).with_external_id.last.external_id)
      end

      # For test/debug only. Should not use this any more.
      desc "test covscan xmlrpc create_errata_diff_scan api call"
      task :scan_create => [:not_production, :ensure_local_kerb_ticket, :environment] do
        task_data = {
          # (This is just some sample data)
          "target"        => "libssh2-1.4.2-1.el6",
          "base"          => "libssh2-1.2.2-11.el6_3",
          "rhel_version"  => "RHEL-6",
          "release"       => "RHEL-6.4.0",
          "errata_id"     => 13846,
          "package_owner" => "kdudka",
          "id"            => Time.now.to_i, # would normally be a record id for an ExternalTestRun
        }
        pp covscan_client.create_errata_diff_scan(task_data)
      end

      # This is useful for testing the qpid listener.
      # See lib/message_bus/qpid_listener/covscan.rb
      #
      # It will make covscan put a test message on the bus like this:
      #
      #    Headers are:
      #    {"qpid.subject"=>"covscan.scan.finished", "x-amqp-0-10.routing-key"=>"covscan.scan.finished"}
      #    Subject: covscan.scan.finished
      #    Sent by User:
      #    Message content:
      #    {"scan_state"=>"QUEUED", "scan_id"=>9842}
      #
      # The scan_state and scan_id are randomly chosen.
      #
      desc "trigger test covscan qpid message"
      task :test_messages => [:development_only, :ensure_local_kerb_ticket, :environment] do
        pp covscan_client(:namespace=>'test').send_message()
      end

    end
  end
end

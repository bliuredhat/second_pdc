require 'net/http'

namespace :test_released_packages do
  task :main, [:version_1, :version_2, :errata_host, :vault_pass_file, :output_directory] => :environment  do |t, args|
    ver1 = args[:version_1] || '3.10.5.0-0'
    ver2 = args[:version_2] || 'develop'
    dir  = args[:output_directory] || "released_packages_dir"
    vault_pass_file = args[:vault_pass_file] || "~/.vault_pass.txt"
    host = args[:errata_host] || "0.0.0.0:3000"

    print "Starting test...\n"
    print "Compare versions: #{ver1} and #{ver2}\n"
    print "Errata host: #{host}\n"
    print "Ansible vault password file: #{vault_pass_file}\n"
    print "Output directory: #{dir}\n"
    print "\n"

    mk_new_dir(dir)

    [ver1, ver2].each do |revision|
      checkout_revision(revision)
      Rake::Task["test_released_packages:get"].invoke(revision, host, dir)
      Rake::Task["test_released_packages:get"].reenable
    end

    Rake::Task["test_released_packages:compare_versions"].invoke(ver1, ver2, dir)
    Rake::Task["test_released_packages:do_tps_tests"].invoke(host, vault_pass_file, dir)
  end

  task :get, [:prefix, :errata_host, :output_directory] => :environment do |t, args|
    prefix = args[:prefix]
    host   = args[:errata_host]
    dir    = args[:output_directory] || "released_packages_dir"

    start_server

    run_with_clean_up("Get Released Packages from #{host} (#{prefix})") do
      if prefix.blank? || host.blank?
        print "Unknown prefix or host.\n"
        exit
      end

      prefix_dir = "#{dir}/#{prefix}"
      mk_new_dir(prefix_dir)

      counter = 0
      status = ""
      active_errata = Errata.active.where("status != ?", "NEW_FILES")
      total_errata = active_errata.count

      active_errata.each do |errata|
        status = "Calling get_released_packages. #{counter += 1} of #{total_errata} errata"
        print "\r#{status}"
        [:rhn, :cdn].each do |dist|
          begin
            result = get_released_packages(host, errata.id, dist)
          rescue Timeout::Error => error
            result = {}
            print "ERROR: call #{dist} #{errata.id} #{error.message}\n"
          end

          write_content_to_file("#{prefix_dir}/#{dist}_#{errata.id}.txt", JSON.pretty_unparse(result.sort))
        end

        break if ENV['limit'] && counter > ENV['limit'].to_i
        $stdout.flush
      end
    end
  end

  task :compare_versions, [:version_1, :version_2, :output_directory] do |t, args|
    ver1 = args[:version_1]
    ver2 = args[:version_2]
    dir  = args[:output_directory] || "released_packages_dir"

    run_with_clean_up("Compare Released Packages Outputs") do
      if ver1.blank? || ver2.blank?
        print "No old and new versions are provided.\n"
        return
      end

      print "Comparing the outputs of #{ver1} and #{ver2}\n"
      errata_not_match = []

      Dir.glob("#{dir}/#{ver1}/*").each do |filename_ver1|
        filename_ver2 = "#{dir}/#{ver2}/#{File.basename(filename_ver1)}"
        content_1 = IO.read(filename_ver1)
        content_2 = IO.read(filename_ver2)

        if content_1 != content_2
          print "- *ERROR* #{filename_ver1} not match.\n"
          print "- vimdiff #{filename_ver1} #{filename_ver2}\n"
          # get errata id
          errata_not_match << filename_ver2.match(/\_(\d+)\.txt/)[1]
        end
      end

      print "\n#{errata_not_match.uniq.size} output(s) not match.\n"
      write_content_to_file("#{dir}/unmatched_errata.txt", errata_not_match.uniq.join("\n")) if errata_not_match.any?
    end
  end

  task :do_tps_tests, [:errata_host, :vault_pass_file, :output_directory] => :environment do |t, args|
    run_with_clean_up("Test Released Packages in TPS Stable Systems") do
      start_server

      dir = args[:output_directory] || "released_packages_dir"
      exit if File.size?("#{dir}/unmatched_errata.txt").nil? || !run_tps_test?

      host = args[:errata_host]
      vault_pass_file = args[:vault_pass_file] || "~/.vault_pass.txt"
      errata_ids = IO.read("#{dir}/unmatched_errata.txt").split(/\s+/)

      if host.blank? || errata_ids.blank?
        print "Missing errata host or errata ids.\n"
        return
      end

      log_path = "#{Dir.pwd}/#{dir}/tps_test_results"
      mk_new_dir(log_path)

      #errata_ids = [
      #  18344
      #  18839 #,19371,18945,19389,18437, 19055,19085,18704,19258,18997,18344,18993,19305,18349,18503
      #  #19276,18713,19054,19395,19052,18948,18389,18861,18417,18881,18431,18843,18768,18919,18674,
      #  #18816,18970,19369,18655,19267,19311,18466,19391,19341,18513,18979
      #]

      Errata.where(:id => errata_ids).each do |erratum|
        Dir.chdir("test/ansible") do
          do_tps_make_list(erratum, host, vault_pass_file, log_path)
        end
      end
    end
  end

  def do_tps_make_list(erratum, host, vault_pass_file, log_path)
    short_et = erratum.shortadvisory
    print %Q(ERRATA_XMLRPC="#{host}" tps-make-lists -e #{short_et}\n)

    tps_stream_threads = []
    streams = get_tps_streams(erratum)

    streams.each do |stream|
      tps_stream_threads << Thread.new do
        begin
          output_file = "#{log_path}/#{short_et}-#{stream}.log"
          messages = ["- #{stream} TPS stream."]

          ansible_command = %Q(ansible-playbook -e "target=#{stream} xmlrpc_host=#{host} errata_id=#{short_et}" -v -s playbooks/tps_tests.yml --vault-password-file #{vault_pass_file} 2> /dev/null)

          result = ""
          result = `#{ansible_command}`

          write_content_to_file(output_file, result)

          if result =~ /no hosts matched/
            messages << "*SKIP*. Stable system not found."
          elsif !$?.success?
            messages << %Q(*FAIL*. See "#{output_file}" for more information)
          else
            messages << "*PASS*"
          end
          print "#{messages.join(" ")}\n"
        rescue StandardError => error
          print "#{error.message}\n"
          Thread.current.exit
        end
      end
    end

    tps_stream_threads.each do |t|
      t.join
    end
  end

  def run_with_clean_up(title)
    print "\n*******#{title}***********\n\n"
    start_time = Time.now

    begin
      yield
    ensure
      kill_server
    end

    print "\nTime spent #{Time.now - start_time}\n"
    print "\n************************************************************************\n"
  end

  def run_tps_test?
    return ENV['assume_yes'] || ask_for_yes_no("Run tps tests on stable systems for unmatched results?")
  end

  def mk_new_dir(path)
    rm_rf(path)
    mkdir(path)
  end

  def get_tps_streams(erratum)
    all_tps_streams = [];
    erratum.errata_brew_mappings.for_rpms.each do |m|
      m.build_product_listing_iterator do |_, variant, _, arch_list|
        arch_list.each do |arch|
          all_tps_streams << "#{variant.get_tps_stream}-#{arch.name}"
        end
      end
    end
    all_tps_streams.compact.uniq
  end

  def checkout_revision(revision)
    print "Checking out #{revision}...\n"
    result = system("git checkout #{revision} 2> /dev/null")
    unless result
      print "\nError checking out revision #{revision}. #{$?}"
      exit
    end
  end

  def kill_server
    rails_pid_file = 'tmp/pids/server.pid'
    # Returns nil if file_name doesn’t exist or has zero size, the size of the file otherwise
    return if File.size?(rails_pid_file).nil?

    begin
      rails_pid = IO.read(rails_pid_file)
      print "Killing server with rails pid #{rails_pid}...\n"
      Process.kill('INT', rails_pid.to_i)
    rescue StandardError
    end
  end

  def start_server
    kill_server
    print "Starting server...\n"
    system("rails s -d 2> /dev/null")
    retry_count = 0

    begin
      retry_count += 1
      if !(ready = check_host_ready?)
       print "Failed to ping the http server. Sleep 2 seconds and retry.\n"
       sleep 2
      end
    end while !ready || retry_count < 10

    if !ready
     print "Giving up\n"
     exit
    end
    print "Server started.\n"
  end

  def check_host_ready?
    begin
      if (res = do_http_request).code != "200"
        return false
      end
    rescue StandardError => error
      return false
    end
    return true
  end

  def do_http_request(opts = {})
    uri = opts.delete("uri") || URI.parse("http://0.0.0.0:3000")
    timeout = opts.delete("timeout") || 30
    request = Net::HTTP::Get.new(uri.request_uri)
    opts.each_pair {|k,v| request[k] = v}

    return Net::HTTP.start(uri.host, uri.port) {|http|
      http.read_timeout = timeout
      http.request(request)
    }
  end

  def get_released_packages(host, errata_id, dist)
    type = dist == :rhn ? 'channel' : 'pulp'
    uri = URI.parse("http://#{host}/errata/get_released_#{type}_packages/#{errata_id}.json")
    params = {"uri" => uri, "timeout" => 300, 'Accept' => "application/json" }

    output = ActiveSupport::JSON.decode(do_http_request(params).body)
    return output
  end
end

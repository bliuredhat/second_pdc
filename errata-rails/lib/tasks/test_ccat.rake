# These tasks assist in testing CCAT.
#
# They may be used to do a simple import of CCAT data into errata tool for
# testing.

require 'net/https'
require 'json'

namespace :test_ccat do
  ARCHIVE_BASE_PATH = {
    :auto => 'nest.test.redhat.com/mnt/qa/content_test_results/ccat/errata',
    :manual => 'nest.test.redhat.com/mnt/qa/content_test_results/ccat/manual',
  }
  LATEST_BUILD_URL = {
    :auto => 'https://content-test-jenkins.rhev-ci-vms.eng.rdu2.redhat.com/job/cdn_content_validation/lastCompletedBuild/api/json',
    :manual => 'https://content-test-jenkins.rhev-ci-vms.eng.rdu2.redhat.com/job/cdn_content_validation_manual/lastCompletedBuild/api/json'
  }

  desc 'Enable CCAT testing for all workflow rule sets'
  task :enable => :environment do
    StateMachineRuleSet.all.each do |rs|
      rs.test_requirements << 'ccat'
      rs.save!
    end
    puts "CCAT is now enabled in all rulesets."
  end

  desc 'Disable CCAT testing for all workflow rule sets'
  task :disable => :environment do
    StateMachineRuleSet.all.each do |rs|
      rs.test_requirements -= ['ccat']
      rs.save!
    end
    puts "CCAT is now disabled in all rulesets."
  end

  desc 'Delete all CCAT test results from the database'
  task :delete => :environment do
    ExternalTestRun.
      where(:external_test_type_id => ccat_types).
      delete_all
    puts "All CCAT results deleted from database."
  end

  desc 'Download CCAT result logs (for import_logs)'
  task :fetch_logs => [:fetch_logs_auto, :fetch_logs_manual]

  task :fetch_logs_auto do
    fetch_logs :type => :auto
  end

  task :fetch_logs_manual do
    fetch_logs :type => :manual
  end

  desc 'Import CCAT result logs into database; CCAT must be enabled first'
  task :import_logs => [:environment, :fetch_logs] do
    import_logs :type => :auto
    import_logs :type => :manual
  end

  def fetch_logs(opts)
    (from_build, to_build) = get_from_to_build(opts)

    (from_build..to_build).each do |build_id|
      begin
        fetch_log opts, build_id
      rescue => e
        puts "Cannot fetch #{build_id}: #{e}\n  Continuing..."
      end
    end
  end

  def import_logs(opts)
    type = opts[:type]
    path = ARCHIVE_BASE_PATH[type]
    Dir.glob("tmp/#{path}/*/logs/*.json").sort.each do |filename|
      begin
        import_log(opts, filename)
      rescue => e
        puts "WARNING: could not import #{filename}\n  #{e}"
      end
    end
  end

  def import_log(opts, filename)
    basename = File.basename(filename)
    test_id = File.basename(File.dirname(File.dirname(filename))).to_i
    timestamp = File.mtime(filename)

    if basename =~ %r{^[0-9]+-listing\.json$}
      # Currently not using these
      return
    elsif basename =~ %r{^[0-9]+\.json$}
      parsed = File.open(filename) do |io|
        JSON.parse(io.read)
      end
      ActiveRecord::Base.transaction do
        import_parsed(opts, test_id, timestamp, parsed)
      end
    else
      puts "Unrecognized filename #{filename}, ignoring"
    end
  end

  def import_parsed(opts, test_id, timestamp, data)
    result_data = data.find{ |x| x['id'].present? }

    errata_id = result_data['id'].to_i
    result    = result_data['result']

    test_type = ccat_type(opts)

    if ExternalTestRun.where(:external_id => test_id,
                             :external_test_type_id => test_type).any?
      # Already have this
      return
    end

    errata = Errata.find_by_id(errata_id)
    if !errata
      puts "Test #{test_id}: #{errata_id} not in my DB, ignoring"
      return
    end

    run = ExternalTestRun.create!(
      :external_test_type => test_type,
      :external_message => nil,
      :external_status => result,
      :external_id => test_id,
      :created_at => timestamp,
      :updated_at => timestamp,
      :status => (result == 'PASS' ? 'PASSED' : 'FAILED'),
      :errata => errata)

    # Supersede any existing earlier active runs
    ExternalTestRun.
      where(:errata_id => errata, :external_test_type_id => ccat_types).
      where(:active => true).
      where('updated_at < ?', run.updated_at).
      each do |old_run|
        old_run.superseded_by_id = run.id
        old_run.active = false
        # if this was the real data, then this object would have been updated
        # at the same time the new run was added
        old_run.updated_at = timestamp
        old_run.save!
      end

    puts "Imported: test #{test_id}: #{errata_id} #{result}"
  end

  def fetch_log(opts, build_id)
    logs_path = "#{ARCHIVE_BASE_PATH[opts[:type]]}/#{build_id}/logs"
    return if File.exists?("tmp/#{logs_path}")

    cd 'tmp' do
      sh "wget --no-parent --recursive --accept .json http://#{logs_path}"
    end
  end

  def get_from_to_build(opts)
    type = opts[:type]
    from_build = (ENV["FROM_#{type}_BUILD"] || -1).to_i
    if from_build == -1
      from_build = (type.to_s.downcase == 'auto' ? 2161 : 392)
    end
    [from_build, get_to_build(opts)]
  end

  def get_to_build(opts)
    type = opts[:type]
    from_env = ENV["TO_#{type}_BUILD"]
    if from_env
      return from_env.to_i
    end

    # Attempt lookup from Jenkins
    parsed_url = URI.parse(LATEST_BUILD_URL[type])
    http = Net::HTTP.new(parsed_url.host, parsed_url.port)
    http.use_ssl = true

    build = http.request_get(parsed_url.path).body

    # assign to env for use in later tasks
    JSON.parse(build)['number'].tap do |num|
      ENV["TO_#{type}_BUILD"] = num.to_s
    end
  end

  def ccat_type(opts)
    type = opts[:type]
    name = (type == :auto ? 'ccat' : 'ccat/manual')
    ExternalTestType.find_by_name!(name)
  end

  def ccat_types
    ExternalTestType.where(:name => %w[ccat ccat/manual])
  end
end

namespace :rpmdiff do

  #
  # This task can be used to reschedule an rpmdiff run with a manually set
  # baseline, (which might be easier than troubleshooting and fixing whatever
  # released package issue is the root cause of the incorrect old version).
  #
  task :reschedule_with_old_version => :environment do

    run_id = ENV['RUN_ID'] or raise "Please set RUN_ID!"
    old_version = ENV['OLD_VERSION'] or raise "Please set OLD_VERSION!"

    rpmdiff_run = RpmdiffRun.find(run_id)
    person = rpmdiff_run.person

    # Sanity check against against typos in old version
    BrewBuild.find_by_nvr("#{rpmdiff_run.package_name}-#{old_version}") or raise "Build for old version doesn't exist!"

    puts "Run id: #{rpmdiff_run.id}"
    puts "Advisory: #{rpmdiff_run.errata.shortadvisory}"
    puts "Person: #{rpmdiff_run.person}"
    puts "Package: #{rpmdiff_run.package_name}"
    puts "New verision: #{rpmdiff_run.new_version}"
    puts "Old version: #{rpmdiff_run.old_version}"

    ActiveRecord::Base.transaction do
      puts "Rescheduling..."
      new_run = rpmdiff_run.reschedule(person)
      puts "New id: #{new_run.id}"
      puts "Old version: #{new_run.old_version}"
      new_run.update_attribute('old_version', old_version)
      puts "Adjusted old version: #{new_run.old_version}"
      puts "https://errata.devel.redhat.com/advisory/#{new_run.errata.id}/rpmdiff_runs"
    end
  end

end

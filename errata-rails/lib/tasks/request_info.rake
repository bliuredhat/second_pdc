namespace :errata do
  # Does a bulk info request on all active errata within a particular release.
  # Created for: https://engineering.redhat.com/rt/Ticket/Display.html?id=391938
  desc 'Bulk request info on all errata in release'
  task :request_info => :environment do
    release_name, user_name, summary, description, role_name = get_env(
      %w(RELEASE  WHO        SUMMARY  DESCRIPTION  ROLE)
    )

    really = ENV['REALLY']
    unless really
      puts '(Will not save anything, since REALLY is not set.)'
    end

    release = Release.find_by_name!(release_name)
    user = User.find_by_name(user_name) or raise "Invalid user #{user_name}"
    role = Role.find_by_name!(role_name)

    errata = release.errata.where(:status => %w(NEW_FILES QE REL_PREP PUSH_READY))
    last_comment = nil

    ActiveRecord::Base.transaction_with_retry do
      errata.each do |e|
        if e.active_info_request
          puts "SKIPPED #{e.id}"
          next
        end

        req = InfoRequest.create!(:errata => e,
                                  :summary => summary,
                                  :description => description,
                                  :info_role => role)
        e.comments.create!(:who => user,
                           :text => ["Information requested from #{role_name}",
                                     summary,
                                     description].join("\n"),
                           :info_request => req)
        last_comment = e.comments.last
        puts "REQUESTED #{e.id}"
      end

      unless really
        puts '(Rolling back changes.)'
        raise ActiveRecord::Rollback
      end
    end

    if last_comment
      puts ['===== sample comment =============',
            last_comment.text,
            '===== end ========================'].join("\n")
    end

    puts 'Done.'
  end

  def get_env(keys)
    keys.map do |key|
      ENV[key] or raise "Must specify #{key} for this task"
    end
  end
end

namespace :debug do
  namespace :rpmdiff do

    #
    # See Bug 1227148
    #
    desc "Autowave safe aarch64 and ppc64le warnings"
    task :autowaive_arch_results => :environment do
      puts "Starting #{Time.now.utc.to_s}"
      puts ""
      quiet = ENV['QUIET'] == '1'

      # Parse the html in the rpmdiff_result.log field and pull out
      # just the message in the right column
      extract_messages = lambda do |log_html|
        log_html.scan(%r{
          <tr>
            <td\svalign="top">.*?<\/td>
            <td>.*?<\/td>
            <td\svalign="top">.*?<\/td>
            <td>.*?<\/td>
            <td\svalign="top">(.*?)<\/td>
          <\/tr>
        }x).map(&:last)
      end

      # For all the messages divide them into safe to waive and unsafe to waive
      safe_unsafe_messages = lambda do |log_html, safe_regex|
        extract_messages[log_html].partition do |m|
          m.match(/^#{safe_regex}$/)
        end
      end

      combos = %w[ppc64le aarch64].product(['appeared', 'gone away'])
      match_strings = combos.map{ |arch, what| "Architecture #{arch} has #{what}" }

      # Use this to pull records out of the database
      like_filter = match_strings.map { |s| "(log like '%>#{s}<%')" }.join(' OR ')

      # It's slow to look through all the results let's limit to active advisories
      # (Maybe some joins would be quicker here, but never mind..)
      active_results = RpmdiffResult.where(:run_id => RpmdiffRun.where(:errata_id => Errata.active, :obsolete => false))

      # Use this to decide if it's safe to waive based on the message content
      regex_filter = match_strings.map{ |s| Regexp.escape(s) }.join("|")
      appeared_only_regex_filter = match_strings.grep(/appeared/).map{ |s| Regexp.escape(s) }.join("|")

      product_versions_allowed = {
        # Depending on when the previous rpm was built there might be appeared or
        # gone away warnings, so allow both to be autowaived.
        'RHEL-7.1.Z' => regex_filter,
        'RHEL-7.1.Z-Supplementary' => regex_filter,
        'RHEL-7.1-EUS' => regex_filter,

        # Only expect 'arch appeared' for these product versions. If the arch is gone
        # away it means there's a problem
        'RHEL-7' => appeared_only_regex_filter,
        'RHEL-7-Supplementary' => appeared_only_regex_filter,
        'FAST7.2' => appeared_only_regex_filter,
      }

      releases_allowed = %w[RHEL-7.2.0 FAST7.2 RHEL-7.1.Z RHEL-7.1.EUS Supplementary-7.1.Z ASYNC]

      # Find the results we might need to waive
      active_results.where(like_filter).each do |result|
        run = result.rpmdiff_run
        product_version = run.errata_brew_mapping.product_version
        errata = run.errata
        release = errata.release
        orig_score = result.rpmdiff_score
        score_name = orig_score.description

        # Skip if it's already waived or a duplicate
        next if ['Waived', 'Duplicate'].include?(score_name)

        puts "Looking at https://#{ErrataSystem::SYSTEM_HOSTNAME}/rpmdiff/show/#{run.id}?result_id=#{result.id}"
        puts "Score: '#{score_name}', Product Version: #{product_version.name}, NVR: #{run.errata_brew_mapping.brew_build.nvr}"
        puts "Advisory: #{errata.fulladvisory}, State: #{errata.status}, Release: #{errata.release.name}"

        unless product_versions_allowed.keys.include?(product_version.name)
          puts "Skipping product version #{product_version.name}."
          puts ""
          next
        end

        unless releases_allowed.include?(release.name)
          puts "Skipping release #{release.name}."
          puts ""
          next
        end

        safe_msgs, unsafe_msgs = safe_unsafe_messages[result.log, product_versions_allowed[product_version.name]]
        puts "Safe messages:\n- #{safe_msgs.join("\n- ")}" unless quiet
        puts "Unsafe messages:\n- " + unsafe_msgs.join("\n- ") unless quiet

        if unsafe_msgs.empty?
          puts "** Safe to waive."

          if ENV['REALLY'] == '1'
            RpmdiffWaiver.transaction do
              # Update score to waived
              result.update_attributes!(:score => RpmdiffScore::WAIVED)

              # Create waiver record
              waiver = result.rpmdiff_waivers.create!(
                :user => User.default_qa_user,
                :description => 'Autowaiving architecture changes related to ppc64le and aarch64 integration. (See BZ#1227148).',
                :old_result => orig_score.id)

            end
            puts "Waived!"
          else
            puts "(Dry run only)"
          end

        else
          puts "** Not safe to waive."

        end

        puts ""
      end

      puts "Finishing #{Time.now.utc.to_s}"
    end

    desc "Report on results waived by this script"
    task :show_autowaives => :environment do
      desc = "Autowaiving arch changes related to ppc64le and aarch64 integration for RHEL 7.2. (See BZ#1227148)"
      RpmdiffWaiver.where(:description => desc).each do |waiver|
        result = waiver.rpmdiff_result
        run = result.rpmdiff_run
        puts "https://#{ErrataSystem::SYSTEM_HOSTNAME}/rpmdiff/show/#{run.id}?result_id=#{result.id} #{waiver.waive_date}"
      end
    end

  end
end

#
# See also lib/tasks/bz_flag_utils.rake
#
namespace :backlog_utils do

  desc "List all bugs"
  task :all_bugs do
    html_mode = ENV['HTML'].present?

    bug_rows = get_data_from_teiid <<-eos

      SELECT
        flagtypes.name,
        bugs.bug_id,
        bugs.bug_status,
        components.name,
        bugs.priority,
        bugs.short_desc,
        bugs.cf_internal_whiteboard,
        bugs.cf_story_points
      FROM
        Bugzilla.bugs
        JOIN Bugzilla.products ON products.id = bugs.product_id
        JOIN Bugzilla.flags ON flags.bug_id = bugs.bug_id
        JOIN Bugzilla.flagtypes ON flagtypes.id = flags.type_id
        JOIN Bugzilla.components on components.id = bugs.component_id
      WHERE
        products.name = 'Errata Tool' AND
        bug_status != 'CLOSED' AND
        flagtypes.name LIKE 'errata-%'
      ORDER BY
        flagtypes.name,
        case bugs.priority
          when 'urgent' then 0
          when 'high' then 1
          when 'medium' then 2
          when 'low' then 10
          else 5
        end,
        case bugs.bug_status
          when 'RELEASE_PENDING' then 1
          when 'VERIFIED' then 2
          when 'ON_QA' then 3
          when 'MODIFIED' then 4
          when 'POST' then 5
          when 'ASSIGNED' then 6
          else 7
        end,
        bug_id desc

    eos

    puts "<!DOCTYPE html><html><head></head><body><pre style='font-family:Liberation Mono, monospace'>" if html_mode

    puts "(#{Time.now.to_s})"

    prev_flag, prev_heading = nil, nil
    points_sum, no_points_count, bugs_count = 0, 0, 0

    show_counts = lambda do
      puts "\n### Total points in #{prev_flag}: #{points_sum}"
      puts "### Bugs/RFEs unestimated: #{no_points_count}/#{bugs_count}"
      points_sum, no_points_count, bugs_count = 0, 0, 0
    end

    bug_rows.each do |bug_fields|
      flag, id, status, component, priority, title, whiteboard, points = bug_fields

      flag.sub!(/errata-/,'')

      heading = "#{flag} #{priority}"
      link = "https://bugzilla.redhat.com/#{id}"
      link = %{<a href="#{link}">#{id}</a>} if html_mode

      title.strip!
      title = CGI::escapeHTML(title) if html_mode

      roadmap = whiteboard =~ /PnT-DevOps-Epic/

      if prev_flag != flag
        show_counts.call if prev_flag
        puts "\n#{'=' * 50}\n* #{flag}"
      end
      puts "\n*** #{heading}" if prev_heading != heading

      puts "#{flag} #{priority[0..0].upcase} #{roadmap ? 'X' : ' '} #{status[0..2]} #{"%3s"%points} #{link} #{component} - #{title}"

      points_sum += points.to_i
      no_points_count += 1 if points == '---'
      bugs_count += 1

      prev_heading = heading
      prev_flag = flag
    end

    show_counts.call

    puts "</pre></body></html>" if html_mode
  end

end

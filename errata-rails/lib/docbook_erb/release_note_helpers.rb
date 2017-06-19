# :simplecov_exclude:
module DocbookErb
  module ReleaseNoteHelpers

    def sort_these_first(value)
      @sort_these_first = value
    end

    def sections
      %w[new preview improved fixed developer]
    end

    def section_title(section)
      titles = {
        'new'       => 'New',
        'preview'   => 'Technical Previews',
        'improved'  => 'Improvements',
        'fixed'     => 'Fixes',
        'developer' => 'Developer Updates',
      }
      titles[section] or raise "Can't find title for #{section}!"
    end

    def title_markup(section)
      "#{section_title(section)}\n---------------------------\n\n"
    end

    def all_content(match)
      match = 'improved|improvement' if match == 'improved'
      Dir["#{content_dir}/*.md"].
        sort_by{ |f| (@sort_these_first||[]).index(File.basename(f).tr('^0-9','')) || 999 }.
        grep(%r{/(#{match})_})
    end

    def all_highlight_content
      sections.map{ |section| highlight_content(section) }.join("\n\n")
    end

    def highlight_content(section)
      all_content(section).map { |f|
        %{<emphasis role="#{section}">#{section}</emphasis>\n:   #{File.read(f).split(/\n/).first.sub(/^### /, '')}}
      }.join("\n\n")
    end

    def all_include_content
      sections.map do |section|
        text = include_content(section)
        "#{title_markup(section)}#{text}" unless text.blank?
      end.compact.join("\n\n")
    end

    def include_content(section)
      all_content(section).map { |f| content_with_bug_message(f) }.join("\n\n")
    end

    def content_with_bug_message(file_name)
      bug_pattern = /_bug(?:|_|-)?(\d+)_/
      bug_matched = file_name.match(bug_pattern)

      unless bug_matched
        abort "#{file_name} does not match the pattern for encoding bug id: #{bug_pattern} }"
      end

      bug_id = bug_matched[1]
      content = File.read(file_name).strip

      # Add the extra text only if it looks like there isn't something
      # there already in the last three lines of the content
      last_three_lines = content.lines.to_a[-3..-1].map(&:chomp).join(' ')
      content += "\n\n#{bug_link_text(bug_id)}" unless last_three_lines =~ /\[bug #{bug_id}\]/i

      content
    end

    def bug_link_text(bug_id)
      "For more information, please see\n#{bug_link(bug_id)}."
    end

    def bug_link(bug_id, text=nil)
      text ||= "Bug #{bug_id}"
      "[#{text}](https://bugzilla.redhat.com/show_bug.cgi?id=#{bug_id})"
    end

    def short_bug_link(bug_id)
      bug_id(bug_id, bug_id)
    end

  end
end

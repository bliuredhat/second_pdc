require 'rss/maker'
require 'socket'
require 'xmlsimple'
require 'builder'
# Write out RSS for an errata

class ErrataRss
  extend ApplicationHelper

  def self.rss_for_errata(errata_id)
    errata = Errata.find(errata_id)
    return if errata.is_embargoed?

    host = Socket.gethostname
    RSS::Maker.make("2.0") do |m|
      m.channel.title = "#{errata.advisory_name} - #{errata.synopsis}"
      m.channel.link = "https://#{host}/advisory/#{errata.id}"
      m.channel.description = "#{errata.advisory_name} - #{errata.synopsis}"

      creation = m.items.new_item
      creation.title =  "New Advisory: #{errata.advisory_name} - #{errata.synopsis}"
      creation.date = errata.created_at.time

      builds = "Brew Builds:<br/>\n" + errata.brew_builds.collect { |build| "<a href=\"#{Brew.base_url}/buildinfo?buildID=#{build.id}\">#{build.nvr}</a>" }.join("<br/>\n")
      bugs = "Bugs: <br/>\n" + errata.bugs.find_all { |b| !b.is_private? }.collect { |b| "<a href=\"https://bugzilla.redhat.com/show_bug.cgi?id=#{b.id}\">#{b.id} - #{b.short_desc}</a>" }.join("<br/>\n")
      jira_issues = Settings.jira_private_only ? [] : errata.jira_issues.only_public.collect{|j| %Q[<a href="#{j.url}">#{j.display_id} - #{j.summary}</a>]}.join("<br/>\n")
      jira_issues = "JIRA issues: <br/>\n" + jira_issues unless jira_issues.empty?
      creation.description = ["New Advisory: #{errata.advisory_name} - #{errata.synopsis}",
                              "Release: #{errata.release.name}",
                              "Created by: #{errata.reporter.to_s}",
                              bugs,
                              jira_issues,
                              builds
                             ].reject(&:empty?).join("<br/>\n")
      
      count = 0
      errata.comments.each do |c|
        count += 1
        i = m.items.new_item
        if c.text =~ /(State changed from .+? to .+?)\s/
          i.title = $1
          if c.text =~ /NEED_RESPIN to NEED_QE/
            i.title = "New Packages Available"
          end
        elsif  c.text =~ /(RPMDiff Result Waived for run [0-9]+)/
          i.title = $1
        elsif c.text =~ /(TPS Job [0-9]+ failed)/
          i.title = $1
        else
          i.title = "Comment from #{c.who.realname} (#{c.who.login_name})"
        end
        i.link = "https://#{host}/advisory/#{errata.id}#c#{count}"
        i.date = c.created_at.time
        text = c.text
        text.gsub!('&amp;#010;', "<br/>")
        text.gsub!("\n", "<br/>")
        text.gsub!(/&#010;/, '<br/>')
        text.gsub!("\\1\\3\n", '<br/>')
        text.gsub!('__div_bug_states_separator','')
        text.gsub!('__end_div','')

        i.description = text
      end

    end

  end

  def self.gen_rss(errata_id)
    content = rss_for_errata(errata_id)
    filename = errata_id.to_s

    # In ruby 1.9 f.write throws an exception sometimes, eg:
    #  'Encoding::UndefinedConversionError: "\xC3" from ASCII-8BIT to UTF-8'
    # Setting mode to 'w:ASCII-8BIT' seems to make the tests pass at least.
    open(Rails.root.join("public/rss/#{filename}.rss"), 'w:ASCII-8BIT') do |f|
      f.write(content)
    end

  end

  def self.gen_opml(group)
    return unless supports_opml?(group)

    xml = ''
    host = Socket.gethostname
    doc = Builder::XmlMarkup.new(:target => xml, :indent => 2)
    doc.instruct!
    doc.opml(:version => "1.0") do |opml|
      opml.head do |h|
        h.title(group.description)
        h.dateModified(Time.now)
      end
      opml.body do |b|
        group.errata.each do |e|
          title = "#{e.advisory_name} - #{e.synopsis}"
          b.outline(:title => title,
                    :description => title,
                    :type => 'rss',
                    :xmlUrl => "https://#{host}/rss/#{e.id}.rss",
                    :htmlUrl => "https://#{host}/advisory/#{e.id}")
        end
      end
    end

    return xml
  end

  def self.regenerate_web_index
    
    opml_files = Dir.entries(Rails.root.join("public/rss/")).select {|e| e =~ /\.opml/}
    return if opml_files.empty?
    host = Socket.gethostname
    index = ''
    doc = Builder::XmlMarkup.new(:target => index, :indent => 2)
    doc.html do |h|
      doc.body do |b|
        b.h1("Available OPML Feeds for Errata Release Groups")
        
        opml_files.each do |file|
          opml =XmlSimple.xml_in(Rails.root.join("public/rss",file).to_s)
          b.p { |para| para.a(opml['head'].first['title'], :href => "https://#{host}/rss/#{file}") }        
        end
      end
    end

    open(Rails.root.join("public/rss/index.html"), 'w') do |f|
      f.write(index)
    end

  end

  def self.write_opml(group_id)
    group = Release.find(group_id)
    return unless supports_opml?(group)
    xml = gen_opml(group)

    filename = group.opml_name + ".opml"
    
    open(Rails.root.join("public/rss/#{filename}"), 'w') do |f|
      f.write(xml)
    end

    regenerate_web_index

    return filename
  end

  def self.supports_opml?(group)
    return group.respond_to?('supports_opml?') && group.supports_opml?
  end

end

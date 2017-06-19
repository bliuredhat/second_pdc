xml.instruct! :xml, :version=>"1.0", :encoding=>"UTF-8"
xml_lang = { 'xml:lang' => 'en_US' }.freeze
xml.advisory(:version => '1.0', :from => 'secalert@redhat.com') do
  xml.id(@errata.advisory_name)
  xml.pushcount(@errata.pushcount)
  xml.product(@errata.product.name)
  xml.type(@errata.fulltype, :short => @errata.errata_type)
  if(@errata.is_security?)
    xml.security(:level => @errata.security_impact)
    xml.synopsis(@errata.synopsis_sans_impact, xml_lang)
  else
    xml.synopsis(@errata.synopsis, xml_lang)
  end
  xml.issued(:date => @errata.issue_date)
  xml.updated(:date => @errata.update_date)
  unless @errata.keywords.blank?
    xml.keywords(@errata.keywords, xml_lang)
  end
  unless @errata.obsoletes.blank?
    xml.obsoletes(@errata.obsoletes, xml_lang)
  end

  xml.references do
    xml.reference(:type => 'self', :href => @errata.errata_public_url)
    @errata.crossref.split(' ').each do |c|
      xml.reference(:type => 'crossreference',  :href => Errata.public_url(c)) do
        xml.advisory(c)
      end
    end

    @errata.all_cves.each do |c|
      xml.reference(:type => 'cve',  :href => cve_url(c)) do
        xml.cve(c)
      end
    end

    refs = @errata.reference.split("\n")
    refs.concat(@errata.jira_issues.only_public.map(&:url).sort) if Settings.jira_as_references
    refs.each do |r|
      xml.reference(:type => 'external',  :href => r)
    end
    
    @errata.bugs.only_public.each do |b|
      xml.reference(:type => 'bugzilla',  :href => b.url) do
        xml.bugzilla(b.id)
        xml.summary(b.short_desc)
      end
    end

    (Settings.jira_private_only||Settings.jira_as_references ? [] : @errata.jira_issues.only_public).each do |j|
      xml.reference(:type => 'jira',  :href => j.url) do
        xml.jira(j.key)
        xml.summary(j.summary)
      end
    end
  end

  [:topic, :description, :solution].each do |sym|
    xml.tag!(sym, 'xml:lang' => 'en') do
      xml.p { |x| x << ERB::Util.html_escape(@errata.send(sym))}
    end
  end

  unless @errata.current_files.empty?
    xml.rpmlist do
      version_files = Hash.new { |hash, key| hash[key] = []}
      @errata.current_files.each { |f| version_files[f.variant] << f }
      version_files.sort_by { |version, _| version.name }.each do |version, files|
        xml.product(:short => version.name) do
          xml.name(version.description)
          files.each do |f|
            xml.file(:name => f.brew_rpm.name_nonvr,
                     :version => f.brew_build.version, 
                     :release => f.brew_build.release,
                     :arch => f.arch.name, 
                     :epoch => f.brew_rpm.epoch) do
              xml.filename(f.brew_rpm.filename)
              xml.sum(f.md5sum, :type => 'md5')
            end
          end
        end
      end
    end
    xml.rpmtext(xml_lang) do
      xml.p("These packages are GPG signed by Red Hat for security. Our key and details on how to verify the signature are available from:")
      xml.a(sig_keys_url, :href => sig_keys_url)
    end
  end
  
  xml.contact(xml_lang) do
    xml.p('The Red Hat security contact is secalert@redhat.com. More details at:')
    xml.a('https://access.redhat.com/security/team/contact/', :href => 'https://access.redhat.com/security/team/contact/')
  end
end

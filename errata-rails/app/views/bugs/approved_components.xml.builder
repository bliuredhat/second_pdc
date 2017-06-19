xml.approved_components(:release => @release.name) do 
  @release.approved_components.each do |pkg|
    xml.package(:name => pkg.name, :devel_owner => pkg.devel_owner.to_s, :qe_owner => pkg.qe_owner.to_s, :has_advisory => @pkg_errata.has_key?(pkg)) do
      if @pkg_errata.has_key?(pkg)
        errata = @pkg_errata[pkg]
        xml.errata(:id => errata.id, :synopsis => errata.synopsis, :status => errata.status)
        bugs = errata.bugs
      else
        bugs = @release.get_bugs(pkg.name)
      end
      xml.bugs do 

        bugs.each do |b|
          xml.bug(:id => b.bug_id,
                  :severity => b.bug_severity,
                  :priority => b.priority,
                  :status => b.bug_status,
                  :description => b.short_desc,
                  :last_update => b.last_updated,
                  :is_blocker => b.is_blocker?,
                  :is_exception => b.is_exception?) do
            unless b.keywords.empty?
              xml.keywords do 
                b.keywords.split(',').each { |k| xml.key(:value => k)}
              end
            end
            
            unless b.issuetrackers.empty?
              xml.issue_trackers do 
                b.issuetrackers.split(',').each {|i| xml.issue(:value => i)}
              end
            end
          end
        end
      end
    end
  end
end

xml.bugs_for_errata(:id => for_errata.id, :synopsis => for_errata.synopsis, :release => for_errata.release.name ) do 
  for_errata.bugs.each do |b|
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


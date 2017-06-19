errata = @errata unless errata
xml.rpmdiff_results(:errata_id => errata.id, :synopsis => errata.synopsis ) do 
  errata.rpmdiff_runs.each do |r|
    xml.rpmdiff_run(:id => r.run_id, :status => r.rpmdiff_score.description, :package => r.package, :obsolete => r.obsolete?)
    
  end
end




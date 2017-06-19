xml.respin_list(:release => @release.name) do 
  @errata_list.each do |e|
    xml.errata(:advisory => e.advisory_name, 
               :respin_count => e.respin_count,
               :qe_group => e.quality_responsibility.name,
               :owner => e.package_owner.to_s, 
               :manager => e.manager.to_s) do 
      @respins[e.id].each do |r|
        xml.respin(:reason => r.added, :date => r.created_at.to_date.to_s)
      end
    end
  end
end

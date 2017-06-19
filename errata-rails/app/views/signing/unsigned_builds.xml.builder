xml.unsigned_builds(:errata_id => @errata.id) do
  @map.keys.each do |nvr|
    xml.brew_build(:nvr => nvr, :sig_key_id => @map[nvr][:sig_key_id], :sig_key_name => @map[nvr][:sig_key_name]) do
      @map[nvr][:rpms].each do |rpm|
        xml.rpm(:path => rpm) 
      end
    end
  end
end




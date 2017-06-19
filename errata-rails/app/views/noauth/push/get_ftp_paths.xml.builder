xml.ftp_paths(:errata_id => @errata.id) do
  @map.keys.each do |nvr|
    xml.brew_build(:nvr => nvr, :sig_key => @map[nvr][:sig_key])
    rpms = @map[nvr][:rpms].keys
    rpms.each do |rpm|
      xml.rpm(:name => rpm) do
        @map[nvr][:rpms][rpm].each do |path|
          xml.ftp_path(:path => path)
        end
      end
    end
  end
end




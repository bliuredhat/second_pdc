xml.channel_packages(:errata => @errata.id) do 
  @channel_files.each_pair do |channel, files|
    xml.channel(:channel => channel) do
      files.each do |f|
        xml.file f
      end
    end
  end  
end

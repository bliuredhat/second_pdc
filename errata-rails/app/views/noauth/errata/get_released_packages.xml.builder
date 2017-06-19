xml.released_packages(:errata => @errata.id, :version => params[:version], :arch => params[:arch]) do 
  @files.each do |f|
    xml.file f
  end  
end

xml.bugs_for_release(:id => @release.url_name, :name => @release.name, :product => @release.product.name ) do 
  @release.errata.each do |errata|
    xml << render(:file => '/bugs/for_errata.xml.builder', :use_full_path => true, :locals => { :errata => errata})
  end
end


module UrlFinder
  
  def url_find(id)
    if id.class == Fixnum || id =~ /^[0-9]+$/
      return find_by_id(id.to_i)
    end
    return find_by_url_name(id)
  end
end

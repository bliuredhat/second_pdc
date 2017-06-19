json.array! @all_repos do |c|
  json.partial! 'channel', :channel => c
  json.active @linked_repos.include?(c)
  if @indirect_repos.include?(c)
    json.linked_from do
      json.id c.product_version.id
      json.name c.product_version.name
      json.linked_to_variant do
        json.id @linked_repos[c].variant.id
        json.name @linked_repos[c].variant.name
      end
    end
  end
end

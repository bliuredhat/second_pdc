json.array!((@active_dists + @available_dists).uniq.sort_by(&:id)) do |dist|
  json.enabled @active_dists.include?(dist)
  json.set!(dist_type, dist.attributes.slice(*%w[name id]))
end

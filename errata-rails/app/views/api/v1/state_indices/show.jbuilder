json.data @state_indices do |resource|
  json.id resource.id
  json.partial! 'state_index', :resource => resource
end

json.data @comments do |resource|
  json.id resource.id
  json.type resource.type
  json.partial! 'comment', :resource => resource
end

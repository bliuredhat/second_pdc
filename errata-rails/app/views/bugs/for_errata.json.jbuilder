json.array! @errata.bugs do |bug|
  json.partial! "/bugs/bug", :bug => bug
end

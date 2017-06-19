json.array! @erratas do |e|
  json.partial! "advisory", :advisory => e
end

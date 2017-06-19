json.array! @errata_list do |e|
  json.partial! "/errata/advisory", :advisory => e
end

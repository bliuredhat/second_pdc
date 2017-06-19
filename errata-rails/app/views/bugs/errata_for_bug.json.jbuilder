json.array! @filed_bugs.map(&:errata) do |e|
  json.partial! "/errata/advisory", :advisory => e
end

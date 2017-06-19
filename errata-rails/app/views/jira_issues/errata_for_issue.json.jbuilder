json.array! @errata do |e|
  json.partial! '/errata/advisory', :advisory => e
end

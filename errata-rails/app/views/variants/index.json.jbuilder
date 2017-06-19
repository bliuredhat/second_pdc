json.array! @variants do |v|
  json.partial! 'variant', :variant => v
end

json.id channel.id
json.type channel.type
json.name channel.name
json.has_stable_systems_subscribed channel.has_stable_systems_subscribed
json.variant do |variant|
  variant.id channel.variant.id
  variant.name channel.variant.name
end
json.arch do |arch|
  arch.id channel.arch.id
  arch.name channel.arch.name
end

json.array! @all_repos do |repo|
  json.partial! "repo", :repo => repo
end

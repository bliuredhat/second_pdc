json.id brew_build.id
json.nvr brew_build.nvr
json.package brew_build.package.attributes.slice('id', 'name')

brew_build.released_errata.tap do |e|
  if e
    val = {:id => e.id, :name => e.advisory_name}
  end
  json.released_errata(val)
end

json.all_errata(brew_build.errata.not_dropped.uniq.map{|e|
  {:id => e.id, :name => e.advisory_name, :status => e.status}
})

json.rpms_signed brew_build.signed_rpms_written?

json.files(brew_build.brew_files.sort_by(&:id_brew)) do |file|
  json.partial! '/api/v1/shared/brew_file', :brew_file => file
end

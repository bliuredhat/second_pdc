json.id brew_file.id_brew

json.path brew_file.file_path

# This is currently exposing only the same "type" info which is
# accepted in our APIs, i.e. RPM or the archive type name.  That means
# no direct info about whether this is an image, maven or win file is
# exposed at the moment.
json.type brew_file.kind_of?(BrewRpm) ? 'rpm' : brew_file.archive_type.name

if brew_file.respond_to?(:arch) && arch=brew_file.arch
  json.arch arch.attributes.slice('id', 'name')
end

json.file do
  json.partial! '/api/v1/shared/brew_file', :brew_file => brew_file_meta.brew_file
end
json.title brew_file_meta.title
json.rank brew_file_meta.rank

json.array! @meta do |meta|
  json.partial! '/api/v1/shared/brew_file_meta', :brew_file_meta => meta
end

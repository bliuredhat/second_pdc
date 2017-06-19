require 'simplecov-rcov'

SimpleCov.formatters = [
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::RcovFormatter
]
SimpleCov.start 'rails' do
  # filter out files that have :simplecov_exclude: as the first line
  add_filter { |src_file| src_file.lines.first.src =~ /:simplecov_exclude:/ }
end

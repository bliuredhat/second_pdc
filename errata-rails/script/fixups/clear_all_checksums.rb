#!/usr/bin/env ruby

require 'optparse'
# Run this script by using rails runner
# RAILS_ENV=production rails runner \
#   script/fixups/clear_all_checksums.rb -n {build.nvr}
#
# Add -r or --really to commit the changes.
#

def main
  options = {}

  parser = OptionParser.new do |opts|
    opts.banner = "Usage: rails runner script/fixups/clear_all_checksums.rb [options]"
    opts.separator "Remove all the checksums of a build"
    opts.separator "Options:"
    opts.on '-nNVR', '--nvr NVR', "BrewBuild's NVR to remove checksums, mandatory field" do |nvr|
      options[:nvr] = nvr
    end
    opts.on '-r', '--[no-]really', 'Commit the changes' do |really|
      options[:really] = really
    end
  end

  begin
    parser.parse!
    nvr = options[:nvr] or raise OptionParser::MissingArgument,  'nvr'
  rescue OptionParser::ParseError => e
    puts e
    puts parser
    exit
  end

  really = options[:really]

  unless really
    puts "(Will not destroy anything, since you didn't specify --really )"
  end

  begin
    build = BrewBuild.find_by_nvr(nvr) or raise "Invalid BrewBuild NVR: #{nvr}"
  rescue => e
    puts e
    exit
  end

  deleted_sha256sum = []
  deleted_md5sum = []
  ActiveRecord::Base.transaction_with_retry do
    deleted_sha256sum = Sha256sum.where(:brew_file_id => build.brew_files).destroy_all
    deleted_md5sum = Md5sum.where(:brew_file_id => build.brew_files).destroy_all

    deleted_sha256sum.each do |c|
      puts "Deleted Sha256sum id #{c.id} with checksum #{c.value} for file #{c.brew_file_id} with sig_key #{c.sig_key_id} created at #{c.created_at}"
    end

    deleted_md5sum.each do |c|
      puts "Deleted Sha256sum id #{c.id} with checksum #{c.value} for file #{c.brew_file_id} with sig_key #{c.sig_key_id} created at #{c.created_at}"
    end

    puts ["==== #{deleted_sha256sum.count} Sha256sum deleted"]
    puts ["==== #{deleted_md5sum.count} Md5sum deleted"]

    unless really
      puts '(Rolling back changes.)'
      raise ActiveRecord::Rollback
    end
  end

   puts 'Done.'
end

main if __FILE__ == $0

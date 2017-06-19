#!/usr/bin/env ruby
require 'krb_cmd_setup'
include KrbCmdSetup
require 'optparse'
require 'fileutils'

class Arguments < Hash
  def initialize(args)
    super()
    self[:errata_ids] = []
    opts = OptionParser.new do |opts|
      opts.banner = "Usage: #$0 [options]"
      opts.on('--advisory [ADVISORY]', 'Sign builds in  [ADVISORY]. Advisory (RHBA-2009:1350) or numeric id both work.') do |errata|
        self[:errata_ids] << errata
      end
      opts.on('--list-requests',
              'List errata available to sign') do
        self[:listrequests] = true
      end
      opts.on('--signall',
              'Signs all open requests') do
        self[:signall] = true
      end
      opts.on_tail('-h','--help', 'display this help and exit') do
        puts opts
        exit
      end
    end

    opts.parse!(args)
  end
end



def copy_files_to_tmp(build, signdir)
  return unless in_production?
  build.brew_rpms.each do |r|
    FileUtils.cp r.file_path, signdir
  end
end

def sign_build(build, key, signdir)

  keyname = key.sigserver_keyname
  puts "Signing #{build.nvr} with key #{keyname}"
  files = build.brew_rpms.collect { |r| "#{signdir}/#{r.rpm_name}" }

  if in_production?
    puts "Signing rpms"
    res = `rpm-sign --key=#{keyname} #{files.join(' ')} 2>&1`
    unless $?.exitstatus == 0
      raise "rpm-sign failure: #{res}"
    end

    puts "Importing signatures into brew"
    files.each do |f|
      res = `brew import-sig #{f} 2>&1`
      unless $?.exitstatus == 0
        raise "sig import failure: #{res}"
      end
    end
    
    puts "Writing signed rpms"
    res = `brew write-signed-rpm #{key.keyid} #{build.nvr}`
    unless $?.exitstatus == 0    
      raise "Error writing signed rpms #{res}"
    end
  end
  
  puts "Done signing #{build.nvr}"
  
  build.mark_as_signed(key)

end


user = get_user
puts "User is #{user.to_s}"
opts = Arguments.new(ARGV)

if opts[:listrequests]
  tosign = Errata.find(:all, :conditions => 'sign_requested = 1')
  if tosign.empty?
    puts "No advisories need signatures."
  else
    puts tosign.collect { |e| e.advisory_name }.join(" ")
  end
  exit
end

tosign = []
if opts[:signall]
  tosign = Errata.find(:all, :conditions => 'sign_requested = 1')
elsif opts[:errata_ids].empty?
  puts "Need at least one advisory to sign!"
  exit
else
  opts[:errata_ids].each do |id|
    tosign << Errata.find_by_advisory(id)
  end
end

if tosign.empty?
  puts "No advisories need signatures."
  exit
end

unless File.exists?("/tmp/brewsign")
  FileUtils.mkdir("/tmp/brewsign")
  FileUtils.chown_R(nil, 'errata', "/tmp/brewsign") if in_production?
end

FileUtils.mkdir_p("/tmp/brewsign/#{user.short_name}")

tosign.each do |errata|
  errata.sign_requested = 0
  errata.save
  
  signdir = "/tmp/brewsign/#{user.short_name}/#{errata.id}"
  FileUtils.mkdir_p(signdir)

  puts "Signing builds for #{errata.id} #{errata.fulladvisory} #{errata.synopsis}"

  signed = []
  errata.errata_brew_mappings.for_rpms.each do |map|
    build = map.brew_build
    next if build.is_signed?
    copy_files_to_tmp(build, signdir)
    
    key = map.product_version.sig_key
    sign_build(build, key, signdir)
    signed << build
  end

  
  if signed.empty?
    puts "No builds signed"
  else

    puts "Signed #{signed.length} builds"    
    comment = "The following brew builds have been signed for the advisory:\n"
    comment += signed.collect { |b| b.nvr }.join("\n")
    
    errata.current_files.each do |f|
      f.update_file_path
      f.save
    end
    errata.comments.create(:text => comment, :who => user)
    errata.activities.create(:what => 'signing', :who => user, :added => signed.collect { |b| b.nvr }.join(", "))
  end
end


puts "Done signing errata"

#!/usr/bin/env ruby
require 'krb_cmd_setup'
include KrbCmdSetup
if RUBY_VERSION < '1.9'
  require 'faster_csv'
else
  require 'csv'
end


get_user('admin')
raise "Need a csv export file! " unless ARGV.first

cyp = if RUBY_VERSION < '1.9'
        FasterCSV.read(ARGV.first)
      else
        CSV.read(ARGV.first)
      end

cyp.shift if cyp.first[0] == 'component'
cyp.each do |c|
  pkg_name = c[0]
  resp_name = c[4]
  pkg = Package.find_by_name(pkg_name)
  unless pkg
    p "New Package #{pkg_name}"
    pkg = Package.make_from_name(pkg_name)
  end
  resp_name = 'Default' if resp_name == 'NONE'
  unless pkg.quality_responsibility.name == resp_name
    p "#{pkg_name} QA changed from #{pkg.quality_responsibility.name} to #{resp_name}"
    resp = QualityResponsibility.find_by_name(resp_name)
    unless resp
      p "#{resp_name} is a new QA Group!"
      owner = User.make_from_login_name(c[5])
      unless owner
        owner = User.find_by_realname(c[6])
      end
      
      resp = QualityResponsibility.create(:name => resp_name, :default_owner => owner)
    end
    
    pkg.quality_responsibility = resp
    pkg.save!    
  end
  
end


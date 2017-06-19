#!/usr/bin/ruby

require 'erb'
require 'ostruct'
require 'fileutils'
require 'date'

require 'rubygems'
require 'json'

module DateDefaults
  # super calls the the default method from OpenStruct which
  # returns nil if there is no such attribute set.
  # The idea is you can specify all these dates manually if you want
  # to, but if you don't specify them an estimate will be used.

  def start_date
    super || raise("start_date is required!")
  end

  # You get an error if the planning period starts the same day as the
  # start date. Don't want to adjust all the dates backwards, so instead use
  # this as the main start date in the tjp file.
  def day_before_start_date
    start_date - 1
  end

  # Let's guess-timate two sprints and a some release prep time
  # (For a release that already happened this will be set explicitly)
  def rpm_ready
    super || start_date + 28 + 3
  end

  # Let's say a few days from eng-ops ticket to deploy
  # (For a release that already happened this will be set explicitly)
  def deployed
    super || rpm_ready + 3
  end

  # Sprint plan day one
  def planning_start
    super || start_date
  end

  def planning_end
    super || planning_start + 1
  end

  def development_start
    super || planning_end
  end

  # A few days for final testing and release prep
  def development_end
    super || rpm_ready - 3
  end

  # Let's say testing happens in parallel but with a few days offset
  def testing_start
    super || development_start + 3
  end

  def testing_end
    super || rpm_ready
  end

  # Don't want any milestone dates to fall on the weekend
  def not_weekend(date)
    case date.strftime('%a')
    when 'Sun' ; date + 1
    when 'Sat' ; date + 2
    else       ; date
    end
  end

  def not_weekend_backwards(date)
    case date.strftime('%a')
    when 'Sun' ; date - 2
    when 'Sat' ; date - 1
    else       ; date
    end
  end

  # Used in the template
  alias_method :nw, :not_weekend
  alias_method :nwb, :not_weekend_backwards
end

class ReleaseSchedule < OpenStruct

  include DateDefaults

  def initialize(args)
    args.each_pair{ |k, v| args[k] = Date.parse(v) if v =~ /^\d\d\d\d-\d\d-\d\d$/ }
    super(args)
  end

  def base_directory
    "cvs/program/errata"
  end

  def schedule_directory
    "#{base_directory}/errata-#{major}.#{minor}-#{maint}"
  end

  def tjp_file
    "#{schedule_directory}/errata-#{major}-#{minor}-#{maint}.tjp"
  end

  def makefile_file
    "#{schedule_directory}/Makefile"
  end

  def tjp_content
    ERB.new(File.read('bin/errata-tjp.erb')).result(binding)
  end

  def makefile_content
    ERB.new(File.read('bin/Makefile.erb')).result(binding)
  end

  def write_files
    FileUtils.mkdir_p(schedule_directory)
    File.open(tjp_file, 'w') { |f| f.write(tjp_content) }
    File.open(makefile_file, 'w') { |f| f.write(makefile_content) }
  end

  def self.do_it(release_schedule_data)
    release_schedule_data.each do |release, dates|
      major, minor, maint = release.split('.')
      new(dates.merge(:major=>major, :minor=>minor, :maint=>maint)).write_files
    end
  end
end

if __FILE__ == $0
  json_file = ARGV[0] or raise "Please specify json file!"
  json_text = File.read(ARGV[0]).gsub(/#.*?$/m, '')
  ReleaseSchedule.do_it(JSON.parse(json_text))
end

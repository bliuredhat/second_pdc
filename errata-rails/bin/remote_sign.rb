#!/usr/bin/env ruby
require 'optparse'
require 'fileutils'
require 'etc'
require 'rubygems'
require 'curb'
require 'json'

class Arguments < Hash
  def initialize(args)
    super()
    self[:errata_ids] = []
    self[:use_kerberos] = true
    self[:server_url] = 'https://errata.devel.redhat.com'
    opts = OptionParser.new do |opts|
      opts.banner = "Usage: #$0 [options]"
      opts.on('--advisory [ADVISORY]', 'Sign builds in  [ADVISORY]. Advisory (RHBA-2009:1350) or numeric id both work.') do |errata|
        self[:errata_ids] << errata
      end
      opts.on('--list-requests',
              'List errata available to sign') do
        self[:listrequests] = true
      end
      opts.on('--revoke-signatures',
              'Revoke signatures for given errata') do
        self[:revoke_signatures] = true
      end
      opts.on('--update-filelist',
              'If this flag is set, the erratum filelist will be automatically updated to point at the signed paths in brew. Otherwise, the update will happen only if the erratum is in ON_RHNQA, or when it is moved into that state') do
        self[:update_filelist] = true
      end
      opts.on('--signall',
              'Signs all open requests') do
        self[:signall] = true
      end
      opts.on('--server-url URL') do |server|
        puts "Server is #{server}"
        self[:server_url] = server
      end
      opts.on('--no-kerb') do
        self[:use_kerberos] = false
      end
      opts.on_tail('-h','--help', 'display this help and exit') do
        puts opts
        exit
      end
    end

    opts.parse!(args)
  end
end

class SigningService
  def initialize(server = 'https://errata.devel.redhat.com', use_kerberos = true)
    puts "Server is #{server} kerb #{use_kerberos}"
    @server = server
    @curl = Curl::Easy.new
    @curl.headers['Accept'] = 'text/plain'
    
    return unless use_kerberos
    @curl.http_auth_types = Curl::CURLAUTH_GSSNEGOTIATE
    @curl.userpwd = ':'
  end

  def in_production?
    'https://errata.devel.redhat.com' == @server
  end
  
  def list_unsigned_errata
    http_request('/signing/list', :http_get)
    return @curl.body_str.split(',')
  end

  def mark_as_signed(errata_id, nvr, key_id)
    http_request("/signing/mark_as_signed/#{errata_id}", :http_post, "brew_build=#{nvr}", "sig_key=#{key_id}")
  end
  
  def remove_needsign_flag(errata_id)
    http_request("/signing/remove_needsign_flag/#{errata_id}", :http_post)
  end

  def revoke_signatures(errata_id)
    http_request("/errata/revoke_signatures/#{errata_id}", :http_post)
  end

  def unsigned_builds(errata_id)
    http_request("/signing/unsigned_builds/#{errata_id}.json", :http_get)
    JSON.parse(@curl.body_str)
  end
  
  private
  def http_request(url, method, *methodargs)
    @curl.url = @server + url
    @curl.send method, *methodargs
    unless @curl.response_code == 200
      raise "HTTP Error: #{@curl.response_code} - #{@curl.body_str}"
    end
  end
end


class PackageSign
  attr_reader :service
  
  def initialize(opts = { })
    @service = SigningService.new(opts[:server_url], opts[:use_kerberos])
    @opts = opts
  end

  def in_production?
    @service.in_production?
  end
  
  def exec_cmd(cmd, msg_on_failure)
    unless in_production?
      puts cmd
      return
    end

    res = `#{cmd} 2>&1`
    info res
    unless $?.exitstatus == 0
      raise "#{msg_on_failure}: #{res}"
    end
  end

  def list_unsigned_errata
    @service.list_unsigned_errata
  end

  def make_tmp_dirs
    return unless in_production?
    unless File.exists?("/tmp/brewsign")
      FileUtils.mkdir("/tmp/brewsign")
      FileUtils.chown_R(nil, 'errata', "/tmp/brewsign")
    end

    FileUtils.mkdir_p("/tmp/brewsign/#{Etc.getlogin}")
  end

  def revoke_signatures
    revoke = @opts[:errata_ids]
    revoke.each do |id|
      puts "Revoking signatures for #{id}"
      @service.revoke_signatures(id)
    end
  end
  
  def sign_packages

    tosign = []
    if @opts[:signall]
      tosign = @service.list_unsigned_errata
    else
      tosign = @opts[:errata_ids]
    end

    if tosign.empty?
      puts "No advisories need signatures."
      exit
    end

    tosign.each do |id|
      @service.remove_needsign_flag(id)
      puts "Signing builds for #{id}"

      unsigned = @service.unsigned_builds(id)
      if unsigned.empty?
        puts "No unsigned builds in errata #{id}"
        next
      end

      signdir = "/tmp/brewsign/#{Etc.getlogin}/#{id}"
      FileUtils.mkdir_p(signdir) if in_production?

      unsigned.keys.each do |nvr|
        copy_files_to_tmp(unsigned[nvr], signdir)
        sign_build(unsigned[nvr], nvr, signdir)
        @service.mark_as_signed(id, nvr, unsigned[nvr]['sig_key_id'])
      end
      puts "Done signing builds for #{id}"
    end
    puts "Done signing errata"
  end
  
  def copy_files_to_tmp(build, signdir)
    return unless in_production?
    build['rpms'].each do |r|
      FileUtils.cp r, signdir
    end
  end
  
  def sign_build(build, nvr, signdir)
    keyname = build['sig_key_name']
    puts "Signing #{nvr} with key #{keyname}"
    rpms = build['rpms'].collect { |r| r.split('/').pop}
    files = rpms.collect { |r| "#{signdir}/#{r}" }

    puts "Signing rpms"
    exec_cmd "rpm-sign --key=#{keyname} #{files.join(' ')} 2>&1", 'rpm-sign failure'
    puts "Importing signatures into brew"
    files.each do |f|
      exec_cmd "brew import-sig #{f} 2>&1", 'sig import failure'
    end
      
    puts "Writing signed rpms"
    exec_cmd "brew write-signed-rpm #{build['sig_key_id']} #{nvr}", "Error writing signed rpms"
    puts "Done signing #{nvr}"
  end
end

opts = Arguments.new(ARGV)
pkg_sign = PackageSign.new(opts)

if opts[:listrequests]
  puts pkg_sign.list_unsigned_errata
  exit
end

if opts[:revoke_signatures]
  pkg_sign.revoke_signatures
  exit
end

pkg_sign.sign_packages

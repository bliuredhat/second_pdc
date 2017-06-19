#!/usr/bin/env ruby
require 'krb_cmd_setup'
include KrbCmdSetup

class CloseBugsHelper < CmdlinePushHelper
  def run!
    get_errata_from_release_or_ids
    @log.info "Submitting jobs to close bugs for #{@errata.length} advisories."
    @errata.each do |e|
      @log.info "Submitting jobs to close bugs for #{e.advisory_name}"
      Bugzilla::CloseBugJob.close_bugs(e)
    end
    @log.info "Jobs submitted. Track at https://errata.devel.redhat.com/background_job"
  end

  protected

  def release_conditions
    "status = 'SHIPPED_LIVE'"
  end

  def check_can_push(errata)
    # TODO finish
    errata.status == State::SHIPPED_LIVE
  end

end

user = get_user('pusherrata', 'releng')

log = Logger.new(STDERR)

opts = CloseBugsHelper.new(ARGV, log, user)
opts.run!









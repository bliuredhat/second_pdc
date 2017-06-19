require 'test_helper'

class DataTest < ActiveSupport::TestCase
  # In certain cases, it makes sense to have invalid records in
  # fixtures, since invalid records can come to exist in production by
  # various means.
  #
  # Expected invalid records can be added to the whitelist here to
  # avoid test failures in this case.
  PERMIT_INVALID = {
    TpsJob => [198289],
  }

  [Arch,
   BlockingIssue,
   BrewBuild,
   BrewRpm,
   BrewTag,
   BrewTagsProductVersion,
   BrewTagsRelease,
   Bug,
   BugsRelease,
   CarbonCopy,
   Channel,
   ChannelLink,
   Comment,
   Content,
   DroppedBug,
   Errata,
   ErrataActivity,
   ErrataBrewMapping,
   ErrataFilter,
   ErrataFile,
   ErrataResponsibility,
   FiledBug,
   FtpExclusion,
   InfoRequest,
   Product,
   ProductVersion,
   PushJob,
   Release,
   ReleaseComponent,
   ReleasedPackage,
   RhelRelease,
   StateIndex,
   RpmdiffRun,
   RpmdiffResult,
   RpmdiffWaiver,
   TpsRun,
   TpsJob,
   User,
   Role,
   UserOrganization,
   Variant ].each do |klass|
    name = "test_#{klass.to_s.underscore}_valid".to_sym
    define_method name do
      validate_records klass
    end
  end
  
  def validate_records(klass)
    #puts "Testing records of type #{klass}"
    list = klass.find :all
    #puts "testing #{list.length} records"
#    list.each { |r| assert r.valid?, "Fixture data failed validation: #{r.inspect} - #{r.errors.full_messages.join("\n")}" }
    problems = []
    list.each do |r|
      pkey = r.send(klass.primary_key)
      begin
        next if r.valid?
        next if PERMIT_INVALID.fetch(klass, []).include?(pkey)
        problems << "#{r.inspect} - #{r.errors.full_messages.join("\n")}"
      rescue => e
        problems << "record #{pkey} validation crashed - #{e.inspect}"
      end
    end
    assert problems.empty?, "#{klass} Fixture data failed validation:\n#{problems.join("\n")}"
  end
end


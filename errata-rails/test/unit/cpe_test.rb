#
# See also rhsa_map_cpe_test
#
require 'test_helper'

class CpeTest < ActiveSupport::TestCase
  test 'cache generation on shipped_live' do
    e = RHSA.find 11110
    refute e.cve.blank?, 'Advisory should have cve data'
    refute cpe_cache_job.exists?, 'Should be no cache job in queue'

    assert_equal 'PUSH_READY', e.status
    e.change_state! 'IN_PUSH', releng_user
    e.change_state! 'SHIPPED_LIVE', releng_user
    assert cpe_cache_job.exists?, 'Cache job should be created after move to shipped live'
  end

  test 'cache generation on cve change' do
    e = RHSA.find 13147
    refute e.cve.blank?, 'Advisory should have cve data'
    assert_equal 'SHIPPED_LIVE', e.status
    refute cpe_cache_job.exists?, 'Should be no cache job in queue'

    e.content.cve = "#{e.cve} CVE-2013-90210"
    e.content.save!
    assert cpe_cache_job.exists?, 'Cache job should be created after cve changed'
  end

  test 'cache generation on text only cpe change' do
    e = RHSA.find 10801
    refute e.cve.blank?, 'Advisory should have cve data'
    assert_equal 'SHIPPED_LIVE', e.status
    refute cpe_cache_job.exists?, 'Should be no cache job in queue'

    e.content.text_only_cpe = "cpe:/a:redhat:jboss_enterprise_application_platform:6::el6"
    e.content.save!
    assert cpe_cache_job.exists?, 'Cache job should be created after cve changed'
  end

  test 'cache generation on variant cpe change' do
    v = Variant.find_by_name '6Server'
    refute v.cpe.blank?, 'Variant should already have cpe data'
    refute cpe_cache_job.exists?, 'Should be no cache job in queue'
    assert v.has_been_shipped_live?, 'This variant should be part of SHIPPED_LIVE advisories'
    v.update_attribute(:cpe, 'cpe:/o:redhat:enterprise_linux:6::snoopy')
    assert cpe_cache_job.exists?, 'Cache job should be created after public cpe changed'
  end

  # Bug 1160075
  test 'cache generation skips non-RPM mappings' do
    # check the testdata to ensure the crashing case is exercised:
    # RHSA, SHIPPED_LIVE, containing a build without RPMs
    e = RHSA.find(16657)
    assert_equal 'SHIPPED_LIVE', e.status

    build = e.brew_builds.first
    assert build.brew_rpms.empty?

    requested_builds = []

    # spy on every request to get brew product listings to ensure they're
    # not fetched for the non-RPM build
    real_fetch = ProductListing.method(:find_or_fetch)
    ActiveSupport::TestCase.with_replaced_method(ProductListing, :find_or_fetch,
      lambda{ |*args|
        # ensure I'm not storing garbage...
        raise ArgumentError unless args[1].kind_of?(BrewBuild)

        requested_builds << args[1]

        real_fetch.call(*args)
      }) do
      Secalert::CpeMapper.cpe_map_since('2012-01-01')
    end

    assert requested_builds.any?, 'no requested product listings (broken mock?)'

    # it should not have tried to get product listings for this build
    # without RPMs
    refute requested_builds.include?(build),
      "incorrectly requested product listings for #{build.nvr}"
  end

  test 'cpe_list for docker advisories' do
    data = [
      [21100, {"cpe:/o:redhat:enterprise_linux:7::server" => ["7Server-7.1.Z"] }],
      [21101, {"cpe:/o:redhat:enterprise_linux:6::server" => ["6Server"]       }],
      [21130, {"cpe:/o:redhat:enterprise_linux:7::server" => ["7Server-7.1.Z"] }],
      [24604, {"cpe:/a:redhat:rhel_extras_other:7"        => ["7Server-EXTRAS"]}]
    ]
    data.each do |id, expected|
      errata = Errata.find(id)
      assert errata.has_docker?
      assert_equal expected, Secalert::CpeMapper.new.cpe_list(errata)
    end
  end

  def cpe_cache_job
    pm = Delayed::PerformableMethod.new(Secalert::CpeMapper, :publish_cache, [Settings.secalert_cpe_starting_year])
    Delayed::Job.where(:handler => pm.to_yaml)
  end
end

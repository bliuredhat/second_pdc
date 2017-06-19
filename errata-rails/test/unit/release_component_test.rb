require 'test_helper'

class ReleaseComponentTest < ActiveSupport::TestCase
  test "approved component marking" do
    r = Release.find_by_name 'RHEL-5.7.0'
    b4r = BugsForRelease.new(r)
    bugs_by_pkg = b4r.eligible_bugs_by_package
    pkgs = Package.where(:name => %w(autofs cman bash))
    pkgs.each {|pk| assert bugs_by_pkg.has_key?(pk), "Missing #{pk.name} in bugs for #{r.name}"}
    components = r.release_components.where(:package_id => pkgs)
    components.each do |comp|
      assert_nil comp.errata,
                 "Release Component for #{comp.package.name} has advisory!"
    end

    advisory = AutomaticallyFiledAdvisory.new(pkgs.map(&:id),
                                              { :product => {:id => r.product.id},
                                                :release => {:id => r.id},
                                                :type => 'RHBA'
                                              })
    assert_valid advisory
    advisory.save!
    assert_equal "autofs bug fix and enhancement update", advisory.errata.synopsis
    assert_equal "Updated autofs packages that fix several bugs and add various enhancements are now available.",
                 advisory.errata.topic

    components = r.release_components.where(:package_id => pkgs)
    components.each do |comp|
      assert_not_nil comp.errata, "Release Component for #{comp.package.name} has blank advisory!"
      assert_equal advisory.errata, comp.errata,
                   "Release Component for #{comp.package.name} has different advisory: #{comp.errata.advisory_name}"
    end

    autofs = pkgs.first
    autofs_bugs = bugs_by_pkg[autofs]
    assert_equal 3, autofs_bugs.length
    autofs_component = ReleaseComponent.find_by_package_id_and_release_id(autofs, r)
    # double check all relations
    assert_not_nil autofs_component.errata, "Release Component for #{autofs_component.package.name} has blank advisory!"
    assert_equal advisory.errata, autofs_component.errata,
                 "Release Component for #{autofs_component.package.name} has different advisory: #{autofs_component.errata.advisory_name}"

    # Advisory should only be removed from component if all bugs are removed
    DroppedBugSet.new(:errata => advisory.errata, :bugs => [autofs_bugs[0]]).save!
    autofs_component = ReleaseComponent.find autofs_component.id
    assert_not_nil autofs_component.errata, "Advisory unset too soon!"

    bad = AutomaticallyFiledAdvisory.new([autofs.id],
                                              { :product => {:id => r.product.id},
                                                :release => {:id => r.id},
                                                :type => 'RHBA'
                                              })

    refute bad.valid?, "Should not be able to create a new advisory with covered components!"

    # Advisory should only be removed from component if all bugs are removed
    DroppedBugSet.new(:errata => advisory.errata, :bugs => [autofs_bugs[1]]).save!
    autofs_component = ReleaseComponent.find autofs_component.id
    assert_not_nil autofs_component.errata, "Advisory unset too soon!"

    # Advisory should only be removed from component if all bugs are removed
    DroppedBugSet.new(:errata => advisory.errata, :bugs => [autofs_bugs[2]]).save!
    autofs_component = ReleaseComponent.find autofs_component.id
    assert_nil autofs_component.errata, "Advisory was not unset!"
    good = AutomaticallyFiledAdvisory.new([autofs.id],
                                         { :product => {:id => r.product.id},
                                           :release => {:id => r.id},
                                           :type => 'RHBA'
                                         })
    assert_valid good
  end

  test 'updates when bug updates' do
    r = Release.find_by_name 'RHEL-5.7.0'
    b4r = BugsForRelease.new(r)
    bugs_by_pkg = b4r.eligible_bugs_by_package
    pkgs = Package.where(:name => %w(autofs bash))
    pkgs.each {|pk| assert bugs_by_pkg.has_key?(pk), "Missing #{pk.name} in bugs for #{r.name}"}
    components = r.release_components.where(:package_id => pkgs)
    components.each do |comp|
      assert_nil comp.errata,
                 "Release Component for #{comp.package.name} has advisory!"
    end

    advisory = AutomaticallyFiledAdvisory.new(pkgs.map(&:id),
                                              { :product => {:id => r.product.id},
                                                :release => {:id => r.id},
                                                :type => 'RHBA'
                                              })
    assert_valid advisory
    advisory.save!

    e = advisory.errata

    r.release_components.where(:package_id => pkgs).each do |comp|
      assert_equal e, comp.errata
    end

    autofs = Package.find_by_name('autofs')
    cman = Package.find_by_name('cman')
    bash = Package.find_by_name('bash')
    assert_equal 0, e.bugs.where(:package_id => cman).count
    assert_equal 3, e.bugs.where(:package_id => autofs).count

    # switch an autofs bug to cman and verify ReleaseComponent is updated
    bug = e.bugs.where(:package_id => autofs).first
    bug.package = cman
    bug.save!

    assert_equal 1, e.bugs.where(:package_id => cman).count
    assert_equal 2, e.bugs.where(:package_id => autofs).count

    # advisory should now have packages: autofs, cman, bash
    r.release_components.where(:package_id => pkgs + [cman]).each do |comp|
      assert_equal e, comp.errata, "mismatch on package #{comp.package}"
    end

    # switch all remaining autofs bugs to cman and verify that the ReleaseComponent
    # link for autofs is dropped
    e.bugs.where(:package_id => autofs).each do |bug|
      bug.package = cman
      bug.save!
    end

    assert_equal 3, e.bugs.where(:package_id => cman).count
    assert_equal 0, e.bugs.where(:package_id => autofs).count

    r.release_components.where(:package_id => autofs).each do |comp|
      assert_nil comp.errata
    end
    r.release_components.where(:package_id => [cman,bash]).each do |comp|
      assert_equal e, comp.errata, "mismatch on package #{comp.package}"
    end

  end

  test "dropping an advisory" do
    r = Release.find_by_name('RHEL-5.7.0')
    pkg = Package.find_by_name('autofs')
    assert r.release_components.uncovered.for_package(pkg).exists?
    assert BugsForRelease.new(r).eligible_bugs_by_package.has_key?(pkg), "bugs should be available"

    # Create rhel 5.7 advisory for autofs
    advisory = AutomaticallyFiledAdvisory.new([pkg.id],
      { :type => 'RHBA', :product => {:id=>r.product.id}, :release => {:id=>r.id} })
    assert_valid advisory
    advisory.save!
    errata = advisory.errata

    # Now autofs is covered by the new errata
    refute r.release_components.uncovered.for_package(pkg).exists?, "package should not be uncovered"
    assert errata.release_components.for_package(pkg).exists?, "errata release component should be added"
    refute BugsForRelease.new(r).eligible_bugs_by_package.keys.include?(pkg), "bugs should no longer be available"

    # Drop the new errata
    errata.change_state!(State::DROPPED_NO_SHIP, User.current_user, "bam!")

    # Autofs should be uncovered again
    assert r.release_components.uncovered.for_package(pkg).exists?, "package should be uncovered"
    refute errata.release_components.for_package(pkg).exists?, "errata release component should be removed"
    assert BugsForRelease.new(r).eligible_bugs_by_package.has_key?(pkg), "bugs should be available again"
  end
end

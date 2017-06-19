require 'test_helper'

class BuildMessagingTest < ActiveSupport::TestCase
  setup do
    @errata = Errata.find(10808)
    @build = BrewBuild.find(207796)
    @pv = @errata.available_product_versions.first
    @tar_type = BrewArchiveType.find_by_name!('tar')
  end

  test 'testdata preconditions' do
    assert_equal 'NEW_FILES', @errata.status
    assert_not_nil @pv
    refute @errata.brew_builds.include?(@build)
  end

  test 'adding a build sends a build added message' do
    expect_send_message('builds.added').once
    expect_send_msg('errata.builds.changed').once

    ActiveRecord::Base.transaction do
      ErrataBrewMapping.create!(
        :errata => @errata,
        :brew_build => @build,
        :product_version => @pv,
        :package => @build.package
      )
    end
  end

  test 'adding multiple mappings for a build sends only one message' do
    expect_send_message('builds.added').once
    expect_send_msg('errata.builds.changed').once

    ActiveRecord::Base.transaction do
      [nil, @tar_type].each do |type|
        ErrataBrewMapping.create!(
          :errata => @errata,
          :brew_build => @build,
          :product_version => @pv,
          :brew_archive_type => type,
          :package => @build.package
        )
      end
    end
  end

  test 'adding a new file type mapping sends no messages' do
    ActiveRecord::Base.transaction do
      ErrataBrewMapping.create!(
        :errata => @errata,
        :brew_build => @build,
        :product_version => @pv,
        :package => @build.package
      )
    end

    expect_no_message

    ActiveRecord::Base.transaction do
      ErrataBrewMapping.create!(
        :errata => @errata,
        :brew_build => @build,
        :product_version => @pv,
        :brew_archive_type => @tar_type,
        :package => @build.package
      )
    end
  end

  test 'removing a build sends a build removed message' do
    mapping = ActiveRecord::Base.transaction do
      ErrataBrewMapping.create!(
        :errata => @errata,
        :brew_build => @build,
        :product_version => @pv,
        :package => @build.package
      )
    end

    expect_send_message('builds.removed').once
    expect_send_msg('errata.builds.changed').once

    ActiveRecord::Base.transaction{ mapping.obsolete! }
  end

  test 'removing multiple mappings for a build sends only one message' do
    mappings = ActiveRecord::Base.transaction do
      [nil, BrewArchiveType.find_by_name!('tar')].map do |type|
        ErrataBrewMapping.create!(
          :errata => @errata,
          :brew_build => @build,
          :product_version => @pv,
          :brew_archive_type => type,
          :package => @build.package
        )
      end
    end

    expect_send_message('builds.removed').once
    expect_send_msg('errata.builds.changed').once

    ActiveRecord::Base.transaction{ mappings.each(&:obsolete!) }
  end

  test 'no removal message sent if other mappings remain' do
    mappings = ActiveRecord::Base.transaction do
      [nil, @tar_type].map do |type|
        ErrataBrewMapping.create!(
          :errata => @errata,
          :brew_build => @build,
          :product_version => @pv,
          :brew_archive_type => type,
          :package => @build.package
        )
      end
    end

    expect_no_message

    ActiveRecord::Base.transaction{ mappings[0].obsolete! }
  end

  test 'adding and removing in a single transaction sends both messages' do
    assert_equal 1, @errata.brew_builds.count

    expect_send_message('builds.removed').once
    expect_send_msg('errata.builds.changed').once
    expect_send_message('builds.added').once
    expect_send_msg('errata.builds.changed').once

    ActiveRecord::Base.transaction do
      @errata.build_mappings.each(&:obsolete!)
      ErrataBrewMapping.create!(
        :errata => @errata,
        :brew_build => @build,
        :product_version => @pv,
        :package => @build.package
      )
    end
  end

  test 'changes are ignored if a rollback occurs' do
    assert_equal 1, @errata.brew_builds.count

    expect_send_message('builds.removed').never
    expect_send_msg('errata.builds.changed').never
    expect_send_message('builds.added').once
    expect_send_msg('errata.builds.changed').once

    ActiveRecord::Base.transaction do
      @errata.build_mappings.each(&:obsolete!)
      raise ActiveRecord::Rollback
    end

    ActiveRecord::Base.transaction do
      ErrataBrewMapping.create!(
        :errata => @errata,
        :brew_build => @build,
        :product_version => @pv,
        :package => @build.package
      )
    end
  end

  def expect_no_message
    MessageBus.expects(:send_message).never
  end

  # ET need to keep messages post on Qpid as well as UMB for a while,
  # and the test try to conver the two destinations during the transition period.
  # expect_send_message is for Qpid
  def expect_send_message(destination)
    MessageBus.expects(:send_message).with{|body,dest,embargoed| destination == dest}
  end

  # expect_send_msg is for UMB
  def expect_send_msg(destination)
    MessageBus.expects(:enqueue).with{|topic, body, header| destination == topic}
  end
end

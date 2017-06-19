require 'test_helper'

class UmbMaterialMessagesTest < ActiveSupport::TestCase

  setup do
    @async = Async.create!(:name => 'ASYNC', :description => 'async')
    @content = Content.new(
      :topic       => 'test',
      :description => 'test',
      :solution    => 'fix it'
    )
    @rhsa  = RHSA.create!(
      :reporter => qa_user,
      :synopsis => 'test advisory',
      :product => Product.find_by_short_name('RHEL'),
      :release => @async,
      :assigned_to => qa_user,
      :security_impact => 'Moderate',
      :release_date => 10.days.from_now,
      :content => @content
    )
  end

  test "creating new embargoed errata sends a message" do
    (topic, message, properties) = message_generated_by do
      RHSA.create!(
        :reporter => qa_user,
        :synopsis => 'test embargoed advisory',
        :product => Product.find_by_short_name('RHEL'),
        :release => @async,
        :assigned_to => qa_user,
        :security_impact => 'Moderate',
        :release_date => 10.days.from_now,
        :content => @content
      )
    end

    assert_equal 'errata.activity.created', topic
    verify_redacted_info(message, properties, 'errata.activity')
  end

  test "changing bugs of embargoed errata sends a message" do
    list = BugList.new(@rhsa.bugs.map(&:id).join(','), @rhsa)
    (topic, message, properties) = message_generated_by do
      list.append(1230395)
      list.save!
    end
    assert_equal 'errata.bugs.changed', topic
    verify_redacted_info(message, properties, 'errata.bugs.changed')
  end

  test 'changing builds of embargoed errata sends a message' do
    build = BrewBuild.find(207796)
    pv = @rhsa.available_product_versions.first

    (topic, message, properties) = message_generated_by do
      ActiveRecord::Base.transaction do
        ErrataBrewMapping.create!(
          :errata => @rhsa,
          :brew_build => build,
          :product_version => pv,
          :package => build.package
        )
      end
    end
    assert_equal 'errata.builds.changed', topic
    verify_redacted_info(message, properties, 'errata.builds.changed')
  end

  test 'changing activity sends a message' do
    (topic, message, properties) = message_generated_by do
      @rhsa.assigned_to = User.find_by_login_name!('kernel-qe@redhat.com')
      @rhsa.save!
    end

    assert_equal 'errata.activity.assigned_to', topic
    verify_redacted_info(message, properties, 'errata.activity')
  end

  def message_generated_by(&block)
    jobs = capture_delayed_jobs(/SendMsgJob/) { yield }

    assert_equal 1, jobs.count
    send_msg_job = jobs.first

    topic = send_msg_job.instance_variable_get(:@topic)
    message = send_msg_job.instance_variable_get(:@message)
    properties = send_msg_job.instance_variable_get(:@properties)
    [topic, message, properties]
  end

  def verify_redacted_info(message, properties, material_key)
    Settings.message_material_keys.fetch(material_key).each do |key|
      if message.has_key?(key)
        assert_equal message.fetch(key), MessageBus::REDACTED
      end
      if properties.has_key?(key)
        assert_equal properties.fetch(key), MessageBus::REDACTED
      end
    end
  end
end

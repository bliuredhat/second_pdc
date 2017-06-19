require 'test_helper'

class OrgChartSynctest < ActiveSupport::TestCase
  DATA_FEW_EMPTY_GROUPS = YAML::load(<<-'eos')
---
  id: 11
  name: ENG Management
  groups:
  - id: 13
    name: First Group
  - id: 14
    name: Middle Group
  - id: 15
    name: Last Group
eos

  DATA_FLAT_GROUP_WITH_USERS = YAML::load(<<-'eos')
---
  id: 11
  name: ENG Management
  users:
  - id: 12
    name: testuser1
  - id: 13
    name: testuser2
  - id: 14
    name: testuser3
eos

  DATA_GROUPS_WITH_USERS = YAML::load(<<-'eos')
---
  id: 11
  name: ENG Management
  users:
  - id: 12
    name: topleveluser
  groups:
  - id: 13
    name: Child Group A
    users:
    - id: 14
      name: userina
  - id: 15
    name: Child Group B
    users:
    - id: 16
      name: userinb
eos

  DATA_DUPES = YAML::load(<<-'eos')
---
  id: 11
  name: ENG Management
  users:
  - id: 12
    name: user_wdupename
  - id: 18
    name: user_wdupeid
  groups:
  - id: 13
    name: group_wdupename
  - id: 14
    name: group_wdupename
  - id: 15
    name: group_wdupeid_a
  - id: 15
    name: group_wdupeid_b
  - id: 17
    name: group_ok
    users:
    - id: 18
      name: user_wdupeid
    - id: 19
      name: user_wdupename
eos

  test 'assigns UserOrganization to orgchart by name' do
    mock_orgchart(DATA_FEW_EMPTY_GROUPS)

    groups = ['ENG Management', 'First Group', 'Middle Group', 'Last Group'].map{|n| UserOrganization.create!(:name => n)}

    logs = with_records([], groups) { capture_logs{do_sync} }
    logs.reject!{|l| l[:msg] =~ /Changed parent/}
    groups.each(&:reload)
    assert_equal 11, groups[0].orgchart_id
    assert_equal 13, groups[1].orgchart_id
    assert_equal 14, groups[2].orgchart_id
    assert_equal 15, groups[3].orgchart_id

    assert_logs_equal <<-'end_logs'.chomp, logs
INFO Assigned ET group ENG Management to OrgChart group 11.
INFO Assigned ET group First Group to OrgChart group 13.
INFO Assigned ET group Last Group to OrgChart group 15.
INFO Assigned ET group Middle Group to OrgChart group 14.
end_logs
  end

  test 'creates UserOrganization by name' do
    mock_orgchart(DATA_FEW_EMPTY_GROUPS)

    logs = nil
    assert_difference('UserOrganization.count', 4) do
      with_records([User.find_by_login_name('ship-list@redhat.com')], []) do
        logs = capture_logs{do_sync}
      end
    end

    logs.reject!{|l| l[:msg] =~ /Changed parent/}

    created_groups = UserOrganization.order('id DESC').limit(4).to_a
    created_groups = created_groups.map{|g| "#{g.orgchart_id} - #{g.name}"}.sort
    assert_equal <<-'end_groups'.chomp, created_groups.join("\n")
11 - ENG Management
13 - First Group
14 - Middle Group
15 - Last Group
end_groups

    assert_logs_equal <<-'end_logs'.chomp, logs
INFO Created new ET group ENG Management for OrgChart group 11.
INFO Created new ET group First Group for OrgChart group 13.
INFO Created new ET group Last Group for OrgChart group 15.
INFO Created new ET group Middle Group for OrgChart group 14.
end_logs
  end

  test 'sets group parent from orgchart' do
    mock_orgchart(YAML::load(<<-'end_yaml'))
---
  id: 11
  name: ENG Management
  groups:
  - id: 12
    name: Child1
    groups:
    - id: 13
      name: Grandchild1
end_yaml

    oc_id = 10
    groups = ['ENG Management', 'Child1', 'Grandchild1'].map{|n| oc_id += 1; UserOrganization.create!(:name => n, :orgchart_id => oc_id)}

    logs = with_records([], groups) { capture_logs{do_sync} }
    groups.each(&:reload)

    assert_equal groups[0], groups[1].parent
    assert_equal groups[1], groups[2].parent

    assert_logs_equal <<-'end_logs'.chomp, logs
INFO Changed parent of Child1 from (none) to ENG Management.
INFO Changed parent of Grandchild1 from (none) to Child1.
end_logs
  end

  test 'sets group name from orgchart' do
    mock_orgchart(YAML::load(<<-'end_yaml'))
---
  id: 11
  name: ENG Management
  groups:
  - id: 12
    name: New Group Name
end_yaml

    groups = [[11,'ENG Management'], [12, 'Some Group']].map{|id,name| UserOrganization.create!(:name => name, :orgchart_id => id)}

    logs = with_records([], groups) { capture_logs{do_sync} }
    logs.reject!{|l| l[:msg] =~ /Changed parent/}

    groups.each(&:reload)
    assert_equal 'New Group Name', groups[1].name

    assert_logs_equal <<-'end_logs'.chomp, logs
INFO Renamed group Some Group to New Group Name.
end_logs
  end

  test 'sets group manager from orgchart' do
    mock_orgchart(YAML::load(<<-'end_yaml'))
---
  id: 11
  name: ENG Management
  owner: jturner
  users:
  - name: jturner
    id: 12
end_yaml

    group = UserOrganization.create!(:name => 'ENG Management', :orgchart_id => 11)
    user = User.find_by_login_name!('jturner@redhat.com')
    user.update_attributes(:orgchart_id => 12, :user_organization_id => group.id)

    logs = with_records([user], [group]) { capture_logs{do_sync} }
    group.reload

    assert_logs_equal <<-'end_logs'.chomp, logs
INFO Changed manager of ENG Management from ship-list@redhat.com to jturner@redhat.com.
end_logs

    assert_equal user, group.manager
  end

  test 'ignores group manager if user is missing from orgchart' do
    mock_orgchart(YAML::load(<<-'end_yaml'))
---
  id: 11
  name: ENG Management
  owner: jturner
end_yaml

    group = UserOrganization.create!(:name => 'ENG Management', :orgchart_id => 11)
    old_manager = group.manager
    user = User.find_by_login_name!('jturner@redhat.com')
    user.update_attributes(:orgchart_id => 12, :user_organization_id => group.id)

    logs = with_records([user], [group]) { capture_logs{do_sync} }
    group.reload

    assert_logs_equal <<-'end_logs'.chomp, logs
WARN Can't find any OrgChart user jturner (for manager of ENG Management).
WARN Can't find any OrgChart user with ID 12 (for updating ET user jturner@redhat.com).
end_logs

    assert_equal old_manager, group.manager
  end

  test 'assigns User to orgchart by name' do
    mock_orgchart(DATA_FLAT_GROUP_WITH_USERS)

    group = UserOrganization.create!(:name => 'ENG Management', :orgchart_id => 11)
    users = %w[1 2 3].map{|n| User.create!(:realname => "Test User #{n}", :login_name => "testuser#{n}@redhat.com", :user_organization_id => group.id)}

    logs = with_records(users, [group]) { capture_logs{do_sync} }
    assert_logs_equal <<-'end_logs'.chomp, logs
INFO Assigned ET user testuser1@redhat.com to OrgChart user 12.
INFO Assigned ET user testuser2@redhat.com to OrgChart user 13.
INFO Assigned ET user testuser3@redhat.com to OrgChart user 14.
end_logs

    users.each(&:reload)
    assert_equal 12, users[0].orgchart_id
    assert_equal 13, users[1].orgchart_id
    assert_equal 14, users[2].orgchart_id
  end

  test 'moves User between groups' do
    mock_orgchart(DATA_GROUPS_WITH_USERS)

    groups = [[11, 'ENG Management'], [13, 'Child Group A'], [15, 'Child Group B']].map do |id,name|
      UserOrganization.create!(:name => name, :orgchart_id => id)
    end
    users = [[12, 'topleveluser'], [14, 'userina'], [16, 'userinb']].map do |id,name|
      User.create!(:login_name => "#{name}@redhat.com", :realname => "Test User #{name}", :orgchart_id => id)
    end

    # start with these users in the wrong group
    users[1].update_attribute(:user_organization_id, groups[2].id)
    users[2].update_attribute(:user_organization_id, groups[1].id)

    logs = with_records(users, groups) { capture_logs{do_sync} }
    logs.reject!{|l| l[:msg] =~ /Changed parent/}
    assert_logs_equal <<-'end_logs'.chomp, logs
INFO Moved topleveluser@redhat.com from group (none) to ENG Management.
INFO Moved userina@redhat.com from group Child Group B to Child Group A.
INFO Moved userinb@redhat.com from group Child Group A to Child Group B.
end_logs

    users.each(&:reload)
    [0,1,2].each do |i|
      assert_equal groups[i], users[i].organization, "mismatch for index #{i}"
    end
  end

  test 'skips OC duplicates' do
    mock_orgchart(DATA_DUPES)

    groups = ['ENG Management', 'group_ok'].map{|name| UserOrganization.create!(:name => name)}
    logs = with_records([], groups) { capture_logs{do_sync} }

    assert_logs_equal <<-'end_logs'.chomp, logs
INFO Assigned ET group ENG Management to OrgChart group 11.
INFO Assigned ET group group_ok to OrgChart group 17.
INFO Changed parent of group_ok from (none) to ENG Management.
WARN Expected a single OrgChart group with ID 15, but found 2. Skipping.
WARN Expected a single OrgChart group with name group_wdupename (for creating an ET group with orgchart_id 13), but found 2. Skipping.
WARN Expected a single OrgChart group with name group_wdupename (for creating an ET group with orgchart_id 14), but found 2. Skipping.
end_logs
  end

  test 'job follows Delayed::Job interface' do
    job = OrgChart::SyncJob.enqueue_once
    assert_not_nil job
    assert_nil OrgChart::SyncJob.enqueue_once

    assert job.payload_object.rerun?
    assert job.payload_object.next_run_time > Time.now
  end

  # this runs a large realistic sync mixing all kinds of cases
  test 'sync orgchart snapshot against fixtures' do
    mock_orgchart(YAML::load(IO.read 'test/data/orgchart/getGroup_snapshot.yml'))

    # Keep the set of users somewhat static so the results of this
    # test don't unexpectedly change when adding new fixtures
    logs = User.with_scope(:find => {:conditions => 'id <= 3000931'}) do
      capture_logs{do_sync}
    end

    logs = logs.map{|log| "#{log[:severity]} #{log[:msg]}"}

    # check various cases to make sure the code really did something.
    # testing the entire output would be too brittle, this is a sampling.

    # there is no such group in orgchart (probably an old name)
    assert logs.include?("WARN Can't find any OrgChart group named JBoss Development (to assign to ET group).")

    # a disabled user (therefore not returned by orgchart)
    assert logs.include?("WARN Can't find any OrgChart user named notting@redhat.com (to assign to ET user).")

    # a duplicate group name which exists in production orgchart
    assert logs.include?("WARN Expected a single OrgChart group with name ENG Engineering Services (for creating an ET group with orgchart_id 102), but found 2. Skipping.")
    assert logs.include?("WARN Expected a single OrgChart group with name ENG Engineering Services (for creating an ET group with orgchart_id 127), but found 2. Skipping.")
    assert_nil UserOrganization.find_by_orgchart_id(102)
    assert_nil UserOrganization.find_by_orgchart_id(127)

    # warnings resulting from the above dupe
    assert logs.include?("WARN Can't find any ET group with OrgChart ID 127 (for user smohan@redhat.com).")

    # a group managed by a user outside of ENG Management
    assert logs.include?("WARN Can't find any OrgChart user tcallawa (for manager of Fedora Engineering).")

    # a group managed by a disabled user (hence omitted from orgchart)
    assert logs.include?("WARN Can't find any OrgChart user llim (for manager of Content Service QE).")

    # a group managed by a user without an ET account
    assert logs.include?("WARN Can't find any ET user with OrgChart ID 9468 (for manager of RHEL Virt).")

    # various operations succeeded
    assert logs.include?("INFO Created new ET group Virtualization Management for OrgChart group 522.")
    assert logs.include?("INFO Assigned ET user jorton@redhat.com to OrgChart user 220.")
    assert logs.include?("INFO Assigned ET group Product Management to OrgChart group 418.")
    assert logs.include?("INFO Changed manager of Quality Engineering from pgampe@redhat.com to mshao@redhat.com.")
    assert logs.include?("INFO Moved noriko@redhat.com from group Localization Services to ENG Localization Services.")
  end

  def assert_logs_equal(expected, logs)
    assert_equal expected, logs.map{|log| "#{log[:severity]} #{log[:msg]}"}.sort.join("\n")
  end

  def do_sync
    OrgChart::SyncJob.new.perform
  end

  def with_records(users=[], groups=[], &block)
    User.with_scope(:find => User.where(:id => users)) do
      UserOrganization.with_scope(:find => UserOrganization.where(:id => groups)) do
        yield
      end
    end
  end

  def mock_orgchart(data)
    ocdata = data
    XMLRPC::OrgChartClient.any_instance.stubs(:getGroup => ocdata)
  end
end

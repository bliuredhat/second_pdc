require 'test_helper'

class RhnMetadataTest < ActiveSupport::TestCase
  test 'no jira issues' do
    e = Errata.where('id not in (select errata_id from filed_jira_issues)').first
    h = Push::Rhn.make_hash_for_push e, 'foo@redhat.com'
    assert_equal [], h['jira_issues']
  end

  test 'no jira issues as reference' do
    Settings.jira_as_references = true

    e = Errata.where('id not in (select errata_id from filed_jira_issues)').first
    h = Push::Rhn.make_hash_for_push e, 'foo@redhat.com'

    refute h.include?('jira_issues')

    # references is not modified
    assert_equal e.reference, h['reference']
  end

  test 'some jira issues' do
    e = Errata.find(7517)
    h = Push::Rhn.make_hash_for_push e, 'foo@redhat.com'
    assert_equal(
      [{"key"=>"HSSCOMFUNC-349",
        "status"=>"In Progress",
        "summary"=>"[pen-test] RHEL 7 systemd security test"},
       {"key"=>"HSSCOMFUNC-550",
        "status"=>"In Progress",
        "summary"=>"systemctl custom service fuzzing test with zzuf"},
       {"key"=>"HSSCOMFUNC-552",
        "status"=>"To Do",
        "summary"=>"CERT BFF(Basic Fuzzing Framework) research"},
       {"key"=>"MAITAI-1249", "status"=>"Closed", "summary"=>"Update UI"},
       {"key"=>"RHOS-504",
        "status"=>"Resolved",
        "summary"=>"TCMS plans that covers robot automation test."},
       {"key"=>"STEP-759",
        "status"=>"Open",
        "summary"=>
         "[Sync]Please Support the mapping field \"jira.watchers\"---\"bug.cc List\""}
      ],
      h['jira_issues']
    )
  end

  test 'some jira issues as only references' do
    Settings.jira_as_references = true

    e = Errata.find(7517)
    h = Push::Rhn.make_hash_for_push e, 'foo@redhat.com'

    assert_equal <<-'eos'.chomp, h['reference']
https://issues.jboss.org/browse/HSSCOMFUNC-349
https://issues.jboss.org/browse/HSSCOMFUNC-550
https://issues.jboss.org/browse/HSSCOMFUNC-552
https://issues.jboss.org/browse/MAITAI-1249
https://issues.jboss.org/browse/RHOS-504
https://issues.jboss.org/browse/STEP-759
eos
  end

  test 'some jira issues combined with existing references' do
    Settings.jira_as_references = true

    e = Errata.find(7517)
    e.content.reference = "Reference 1\nReference 2"
    e.save!

    h = Push::Rhn.make_hash_for_push e, 'foo@redhat.com'

    assert_equal <<-'eos'.chomp, h['reference']
Reference 1
Reference 2
https://issues.jboss.org/browse/HSSCOMFUNC-349
https://issues.jboss.org/browse/HSSCOMFUNC-550
https://issues.jboss.org/browse/HSSCOMFUNC-552
https://issues.jboss.org/browse/MAITAI-1249
https://issues.jboss.org/browse/RHOS-504
https://issues.jboss.org/browse/STEP-759
eos
  end

  test 'appending jira issues to references will not exceed length limit' do
    Settings.jira_as_references = true

    e = Errata.find(7517)
    e.content.reference = "ref\n" * 960
    e.save!

    h = nil
    logs = capture_logs {
      h = Push::Rhn.make_hash_for_push e, 'foo@redhat.com'
    }

    logs = logs.map{|log| "#{log[:severity]} #{log[:msg]}"}
    assert logs.include?('WARN Dropped some JIRA issue references for RHBA-2008:0588-01; exceeded max limit on reference field!')

    assert_equal( e.content.reference + "\n" + <<-'eos'.chomp, h['reference'] )
https://issues.jboss.org/browse/HSSCOMFUNC-349
https://issues.jboss.org/browse/HSSCOMFUNC-550
https://issues.jboss.org/browse/HSSCOMFUNC-552
eos
  end
end

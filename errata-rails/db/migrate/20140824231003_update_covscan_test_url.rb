class UpdateCovscanTestUrl < ActiveRecord::Migration
  # This is the non-production covscan server url. Production one is not changing.
  OLD_URL = "http://uqtm.lab.eng.brq.redhat.com/covscan/waiving/et_mapping/$ID/"
  NEW_URL = "https://uqtm.lab.eng.brq.redhat.com/covscanhub/waiving/et_mapping/$ID/"

  def up
    # No schema change here, just changing some data.
    ExternalTestType.find_by_name!('covscan').update_attribute(:test_run_url, NEW_URL)
  end

  def down
    ExternalTestType.find_by_name!('covscan').update_attribute(:test_run_url, OLD_URL)
  end
end

class UpdateLongDescToRpmdiffTests < ActiveRecord::Migration
  def up
    update(
      'This test verifies that the upstream source tarballs did not change'
    )
  end

  def down
    update(
      'This test verifies that the upstream source tarbals did not change'
    )
  end

  def update(long_desc)
    RpmdiffTest.where(:description => 'Upstream Source').update_all(
      :long_desc => long_desc
    )
  end
end

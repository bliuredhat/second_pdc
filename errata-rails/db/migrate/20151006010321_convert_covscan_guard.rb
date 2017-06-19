class ConvertCovscanGuard < ActiveRecord::Migration
  def up
    type = covscan_type
    return unless type

    # Every existing ExternalTestsGuard is for covscan only.
    ExternalTestsGuard.all.each do |guard|
      guard.external_test_types << type
    end
  end

  def down
    type = covscan_type
    return unless type

    ExternalTestsGuard.all.each do |guard|
      guard.external_test_types -= [type]
    end
  end

  def covscan_type
    ExternalTestType.find_by_name('covscan').tap do |out|
      STDERR.puts "No 'covscan' external test type found. Migration will do nothing." unless out
    end
  end
end

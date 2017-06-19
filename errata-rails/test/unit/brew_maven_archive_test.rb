require 'test_helper'

class BrewMavenArchiveTest < ActiveSupport::TestCase
  test 'file is located under maven structure' do
    assert_equal '/mnt/redhat/brewroot/packages/org.picketbox-picketbox-infinispan/4.0.9.Final/1/maven/org/picketbox/picketbox-infinispan/4.0.9.Final/picketbox-infinispan-4.0.9.Final-sources.jar', BrewMavenArchive.find(701217).file_path
  end
end

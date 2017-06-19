require 'test_helper'

class BrewWinArchiveTest < ActiveSupport::TestCase
  test 'file is located under win' do
    assert_equal '/mnt/redhat/brewroot/packages/spice-usb-share-win/5.0/6/win/spice-usb-share-win_x86.zip', BrewWinArchive.find(152161).file_path
  end

  test 'file is located under relpath when relpath is set' do
    assert_equal '/mnt/redhat/brewroot/packages/spice-usb-share-win/5.0/6/win/pdb/x86/usbrdrctrl.pdb', BrewWinArchive.find(152159).file_path
  end
end

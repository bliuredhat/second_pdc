require 'test_helper'

class FileWithSanityChecksTest < ActiveSupport::TestCase

  def file_contains_content(content)
    assert File.exist?(@file_name)
    refute File.zero?(@file_name)
    assert_equal content, File.read(@file_name)
  end

  def assert_file_untouched
    file_contains_content(@old_stuff)
  end

  def assert_file_updated
    file_contains_content(@new_stuff)
  end

  def write_new_stuff
    @foo.prepare_file { |f| f.write(@new_stuff) }
    assert File.exist?(@temp_name)
    refute File.zero?(@temp_name)
    assert_equal @new_stuff, File.read(@temp_name)
  end

  setup do
    @old_stuff = "old stuff!"
    @new_stuff = "new stuff!"
    @file_name = 'public/foo.txt'
    File.open(@file_name, 'w') { |f| f.write @old_stuff }
    assert_file_untouched
    @foo = FileWithSanityChecks::Base.new(@file_name)
    @temp_name = @foo.temp_name
  end

  test "non-empty file will overwrite existing" do
    write_new_stuff
    @foo.check_and_move
    assert_file_updated
  end

  test "empty file file will not overwrite existing" do
    @foo.prepare_file { |f| } # makes empty file
    assert File.zero?(@temp_name)
    ex = assert_raises(FileWithSanityChecks::ChecksFailedError) { @foo.check_and_move }
    assert_equal "Problem updating foo.txt, keeping old version", ex.message
    assert_file_untouched
  end

  test "non-empty file with some failing validations will not overwrite existing" do
    write_new_stuff
    ex = assert_raises(FileWithSanityChecks::ChecksFailedError) do
      @foo.check_and_move do |file_name|
        File.read(file_name).include?("neeeew") # fail
      end
    end
    assert_equal "Problem updating foo.txt, keeping old version", ex.message
    assert_file_untouched
  end

  test "non-empty file with passing validation will overwrite existing" do
    write_new_stuff
    @foo.check_and_move do |file_name|
      File.read(file_name).include?("new") # pass
    end
    assert_file_updated
  end

  test "chained methods work okay" do
    test_file = "public/bar.txt"
    (file = FileWithSanityChecks::Base.new(test_file)).prepare_file{ |f| f.write('hey') }.check_and_move
    assert_equal File.read(test_file), 'hey'
    file.cleanup
  end

  teardown do
    FileUtils.rm_f(@file_name)
    FileUtils.rm_f(@temp_name)
  end

end

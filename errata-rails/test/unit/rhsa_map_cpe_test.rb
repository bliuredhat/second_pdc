#
# See also cpe_test
#
require 'test_helper'
#
# See bug 740819.
# See also errata_service_test.rb
#
class RhsaMapCpeTest < ActiveSupport::TestCase
  #
  # Going to run this with and without the bug 740819 patch
  # so this will help make sure I didn't break stuff accidentally.
  #
  test "ErrataService#rhsa_map_cpe" do
    service = ErrataService.new
    initial_cpe_list = service.rhsa_map_cpe(2011).sort

    assert_testdata_equal 'cpe_map_2011.txt', initial_cpe_list.join("\n")

    #
    # Get some text only advisories for testing
    #
    text_only_rhsas_in_list = RHSA.where(:text_only=>true, :status=>'SHIPPED_LIVE').where("issue_date > '2011-01-01'").order('fulladvisory desc')

    #
    # These text only advisories are actually already in the cpe list
    # So let's test that quickly, even though it would have failed above
    # (Note they don't have any cpe text yet)
    #
    text_only_rhsas_in_list.each do |rhsa|
      grepped_list = initial_cpe_list.grep(/^#{rhsa.advisory_name}/)
      assert grepped_list.length < 2, "#{rhsa.advisory_name} found in cpe list more than once"
      assert_equal 1, grepped_list.length, "#{rhsa.advisory_name} not found in cpe list"
      assert_equal "#{rhsa.advisory_name} #{rhsa.content.cve} ", grepped_list.first, "unexpected data in cpe list for #{rhsa.advisory_name}"
    end

    #
    # Everything above here should work before after Bug 740819
    # Everything below here only works after Bug 740819 stuff is merged.
    #
    text_only_rhsas_in_list.each_with_index do |rhsa, i|
      rhsa.content.update_attributes(:text_only_cpe=>"TEXTONLYCPE#{i}")
    end

    cpe_list_with_text_only = service.rhsa_map_cpe(2011)

    assert_testdata_equal 'cpe_map_2011_with_textonly.txt', cpe_list_with_text_only.sort.join("\n")

    text_only_rhsas_in_list.each_with_index do |rhsa, i|
      grepped_list = cpe_list_with_text_only.grep(/^#{rhsa.advisory_name}/)
      # Still in the list?
      assert grepped_list.length < 2, "#{rhsa.advisory_name} found in cpe list more than once"
      assert_equal 1, grepped_list.length, "#{rhsa.advisory_name} not found in cpe list"
      # Correct text?
      assert_equal "#{rhsa.advisory_name} #{rhsa.content.cve} TEXTONLYCPE#{i}", grepped_list.first, "unexpected data in cpe list with text only cpe for #{rhsa.advisory_name}"
    end

    # Make sure the other stuff is unchanged
    assert_array_equal initial_cpe_list, cpe_list_with_text_only.map { |line| line.sub(/TEXTONLYCPE\d/,'') }, "somehow something stranged happened to the other cpes"
  end

  test 'create cache cpe map txt file' do
    test_year = 2011
    base_file = "cpe_map_#{test_year}.txt"
    cpe_map_txt_file = Rails.root.join('public', base_file)
    FileUtils.rm_f(cpe_map_txt_file)
    refute File.exist?(cpe_map_txt_file)

    Secalert::CpeMapper.publish_cache(test_year)
    assert File.exist?(cpe_map_txt_file)
    refute File.zero?(cpe_map_txt_file)

    # Might as well check the content also since we have the expected content handy
    # This sorting ignores RHxA prefix, required for later tests to work
    expected = File.read("#{Rails.root}/test/data/cpe_map_2011.txt").chomp.split("\n").sort_by{|e| e.scan(/\d+:\d+/)}
    assert_equal expected, File.read(cpe_map_txt_file).chomp.split("\n").sort_by{|e| e.scan(/\d+:\d+/)}

    # (Putting in some extra effort to test the content for these as well. Not sure if worth it).
    real_data = Secalert::CpeMapper.cpe_map_since_advisories("#{test_year}-01-01").sort

    # Zero or too small, should not overwrite
    [ [], real_data[0..3] ].each do |stub_data|
      Secalert::CpeMapper.stubs(:cpe_map_since_advisories).returns(stub_data)
      ex = assert_raises(FileWithSanityChecks::ChecksFailedError) { Secalert::CpeMapper.publish_cache(test_year) }
      assert_equal "Problem updating #{base_file}, keeping old version", ex.message
      assert_array_equal expected, File.read(cpe_map_txt_file).chomp.split("\n").sort
    end

    # Slightly smaller or bigger, should overwrite
    [ [ 'smaller', real_data[1..-1], expected[1..-1] ],
      [ 'bigger', real_data + real_data[0..0], expected + expected[0..0] ] ].each do |what, stub_data, new_expected_content|
      Secalert::CpeMapper.stubs(:cpe_map_since_advisories).returns(stub_data)
      Secalert::CpeMapper.publish_cache(test_year)
      assert_array_equal new_expected_content.sort, File.read(cpe_map_txt_file).chomp.split("\n").sort, "Comparison failed for #{what} case"
    end

    # (Clean up temp files created by FileWithSanityChecks)
    FileUtils.rm_rf(Dir.glob("/tmp/_et_cpe_map_#{test_year}.txt.*"))
  end

end

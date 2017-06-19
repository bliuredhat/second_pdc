class AddRpmdiffJavaBytecodeTest < ActiveRecord::Migration
  def up
    RpmdiffTest.create!(:test_id => 49,
      :description => 'Java byte code',
      :long_desc => 'This test checks byte code changes in java class files',
      :wiki_url => 'https://docs.engineering.redhat.com/display/HTD/rpmdiff-java-byte-code')
  end

  def down
    RpmdiffTest.where(:description => 'Java byte code').delete_all
  end
end

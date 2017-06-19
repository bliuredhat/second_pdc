require 'test_helper'

class SqlExamplesTest < ActiveSupport::TestCase

  setup do
    sql_dir = Rails.root.join('examples', 'sql')
    @sql_files = Dir["#{sql_dir}/**/*.sql"]
  end

  test "sql examples work okay" do
    assert @sql_files.any?
    @sql_files.each do |sql_file|
      queries = ERB.new(File.read(sql_file)).result.split(/;/).reject(&:blank?)
      queries.each do |query|
        begin
          result = ActiveRecord::Base.connection.execute(query)
        rescue => e
          raise(e, "in #{sql_file.sub("#{Rails.root}/", '')}:\n#{e.message}", e.backtrace)
        end
        assert result.count > 0, "got zero rows from #{sql_file}" unless zero_rows_okay?(sql_file)
      end
    end
  end

  def zero_rows_okay?(file_name)
    file_name =~ /zabbix/
  end

end

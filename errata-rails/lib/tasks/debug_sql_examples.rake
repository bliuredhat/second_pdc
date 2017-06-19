namespace :debug do
  namespace :sql_examples do
    #
    # Example usage:
    # rake debug:sql_examples:run SQL=examples/sql/release_errata_count.sql | more
    #
    desc "Run an sql file with mysql (and show the output)"
    task :run => :development_only do
      sql_file = ENV['SQL'] or raise "Please specify sql file, eg SQL=filename.sql"
      puts sql = ERB.new(File.read(sql_file)).result
      exit if ENV['Y'] == '0'
      ask_to_continue_or_cancel("Will run the above sql. Okay?") unless ENV['Y'] == '1'
      puts %x{echo "#{sql.gsub(/"/, '\"')}" | mysql #{sql_user_opts(db_conf=get_db_conf)} --database=#{db_conf['database']} --table}
    end

    desc "Run sql and dump csv delimited output into a file"
    task :export => :development_only do
      sql_file = ENV['SQL'] or raise "Please specify sql file, eg SQL=filename.sql"
      out_file = "/tmp/#{File.basename(sql_file, '.sql')}.#{Time.now.strftime('%Y%m%d%H%M%S')}.csv"
      sql = ERB.new(File.read(sql_file)).result.strip.sub(/;$/,'') +
        %{ INTO OUTFILE '#{out_file}' FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\\n'; }
      %x{echo "#{sql.gsub(/"/, '\"')}" | mysql #{sql_user_opts(db_conf=get_db_conf)} --database=#{db_conf['database']} --table}
      puts "\n\nWrote to #{out_file}"
    end

  end
end

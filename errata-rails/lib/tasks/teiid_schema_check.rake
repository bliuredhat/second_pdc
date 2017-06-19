namespace :teiid do

  desc "Check the Teiid schema is working okay"
  task :schema_check => [:environment, :not_production] do
    TEIID_REPO = 'git+ssh://code.engineering.redhat.com/hss_teiid.git'
    TEIID_DIR = ENV['HSS_TEIID_DIR'] || Rails.root.join('..', 'hss_teiid')
    ROW_LIMIT = ENV['ROW_LIMIT'] || 5000

    ddl_files = FileList["#{TEIID_DIR}/**/Errata*.ddl"]
    raise "No files found. Perhaps you need to `git clone #{TEIID_REPO} ../hss_teiid`" if ddl_files.empty?

    ddl_files.each do |ddl_file|
      puts "\nReading #{ddl_file.sub("#{TEIID_DIR}/",'')}"
      statements = File.read(ddl_file).split(/;/).map(&:strip).reject(&:blank?)
      puts "Found #{statements.count} sql statements"

      statements.each do |statement|
        raise "Unexpected sql!\n#{statement}" unless statement =~ /^CREATE VIEW "?(\S+)"? AS\s+\((SELECT .*)\)$/im

        view_name, select_sql = $1, $2.
          # Can't handle these Bugzilla joins in Errata_public so let's just remove them
          gsub(/JOIN Bugzilla\.bugs ON Bugzilla\.bugs\.bug_id = Errata_raw\.\S+\.\S*id/, '').
          # Strip some db name prefixes
          gsub(/"?Errata_raw"?./, '').
          gsub(/"?Errata_public"?./, '').
          # Double quotes don't work too well in mysql
          gsub(/"/,'`')

        puts "\n#{select_sql}" if ENV['SHOW_SQL'] == '1'
        print "Testing #{view_name}... "
        begin
          result = ActiveRecord::Base.connection.execute("#{select_sql} LIMIT #{ROW_LIMIT}")
        rescue
          puts select_sql
          raise
        end
        puts "#{result.count}#{'+' if result.count == ROW_LIMIT} rows"

      end

    end
  end

  desc "Run all Teiid example sql"
  task :examples_check => [:environment, :not_production] do
    teiid_examples_dir = "#{Rails.root}/examples/teiid_sql"
    ask_to_continue_or_cancel("\nThis will run all the SQL queries in #{teiid_examples_dir} against Teiid devel. Okay?\n\n")
    FileList["#{teiid_examples_dir}/*.sql"].each do |sql_file|
      sh "env TEIID_HOST=devel #{teiid_examples_dir}/teiid_query.sh #{sql_file}"
    end
  end

end

#
# The Conflux team wants to have some docs on our schema. A quick way to do this is to
# update the 'Performance Book', which already has a (very old and out of date) listing
# of our schema.
#
# These tasks can be used to spit out some json that the Performance Book can use.
# Output will probably end up here. See jfearn for more info on the Performance Book.
# https://engineering.redhat.com/docs/en-US/Engineering_Services_And_Operations/1/html/Performance/apcs04.html
#
# Performance book source repo is here:
#   git+ssh://code.engineering.redhat.com/ESO_Performance.git
#
# Note that there is still a lot of work to be done to populate db/annotations.yml.
# Going to use the old annotations as a starting point.
#
namespace :schema_docs do

  desc "Import legacy annotations. (Should be done once only)."
  task :import_legacy do
    # Get this file by cloning git+ssh://code.engineering.redhat.com/ESO_Performance.git
    LEGACY_PERL_DATA = '../ESO_Performance/scripts/db-schema.d/errata.conf'
    YAML_FILE = 'db/old_annotations.yml'
    json_text = %x{perl -e "use JSON; print encode_json(do '#{LEGACY_PERL_DATA}')"}
    yaml_text = YAML.dump(JSON.load(json_text)['errata']['tables'])
    # Have to fix the nil/null for some reason. Also strip trailing whitespace.
    write_content_to_file(YAML_FILE, yaml_text.gsub(/\s+$/, '').gsub(/nil$/, 'null'))
  end

  desc "Dump json for 'Performance Book'"
  task :dump_json do
    # ////////////////////////////////////////
    # // Warning: major major hackery ahead //
    # ////////////////////////////////////////

    # Stand back while we take a hatchet to ActiveRecord::Schema
    ActiveRecord.send(:remove_const, :Schema)

    # Now hack up a new one
    class ActiveRecord::Schema
      def initialize(app_name, db_name)
        @app_name, @db_name, @tables = app_name, db_name, {}
        @old_annotations = YAML.load_file('db/old_annotations.yml')
        @new_annotations = YAML.load_file('db/annotations.yml')
      end

      def field_annotation(table, field)
        return @new_annotations[table]['fields'][field] if @new_annotations[table]
        return @old_annotations[table]['fields'][field] if @old_annotations[table]
      end

      def table_annotation(table)
        return @new_annotations[table]['description'] if @new_annotations[table]
        return @old_annotations[table]['description'] if @old_annotations[table]
      end

      def self.define(opts={}, &block)
        s = self.new('Errata Tool', 'errata')
        s.instance_eval &block
        puts s.json_dump
      end

      def create_table(table_name, opts={}, &block)
        @current_table = table_name.to_s
        primary_key = opts[:primary_key] || 'id'
        @tables[@current_table] ||= { 'description'=>table_annotation(@current_table), 'fields'=>{primary_key=>'Primary key'} }
        yield self # Could make another class here, but let's not bother..
        @current_table = nil
      end

      def method_missing(method_name, *args, &block)
        if @current_table
          # Catches t.string, t.integer, etc
          field = args[0]
          annotation = field_annotation(@current_table, field)
          @tables[@current_table]['fields'][field] = annotation
        elsif method_name.to_s == 'add_foreign_key'
          from_table, from_fields, to_table, to_fields = *args
          # Hopefully we don't have any compound foreign keys..
          # otherwise from_fields.first is no good
          raise "compound foreign keys!" if from_fields.length > 1 || to_fields.length > 1
          message = "Foreign key to #{to_table}(#{to_fields.first})"
          current = @tables[from_table]['fields'][from_fields.first]
          @tables[from_table]['fields'][from_fields.first] = [current, message].compact.join('. ') unless current && current.include?(message)
        else
          # Ignore add_index and anything else.
          #puts "#{method_name}"
        end
      end

      def json_dump
        ver_rel = RpmSpecFile.current.version_release

        JSON.pretty_generate({
          #@app_name => {
          'errata' => {
            'connection' => {
              'eso_database_name' => @db_name
            },
            'description' => "Database schema for Errata Tool version #{ver_rel}",
            'tables' => @tables
          }
        })
      end
    end

    # Now feed the db/schema DSL into our hacked up ActiveRecord::Schema
    load('db/schema.rb')
  end

  desc "Dump sql schema"
  task :dump_sql do
    ver_rel = RpmSpecFile.current.version_release
    db_conf = get_db_conf
    puts "-- Errata Tool #{ver_rel}"
    puts "-- -----------------------------\n\n\n"
    sh "mysqldump --add-drop-table=false --no-data #{sql_user_opts(db_conf)} #{db_conf['database']}"
  end

  def publish_schema_file(src)

    filename = ENV['CURRENT'] ? 'current' : RpmSpecFile.current.version_release
    sh "scp #{src} errata-devel.app.eng.bos.redhat.com:/var/www/apidocs/schema/#{filename}#{File.extname(src)}"
    puts "Published to http://apidocs.errata-devel.app.eng.bos.redhat.com/schema/"
  end

  desc "Publish schema SQL"
  task :publish_sql do
    sh "rake schema_docs:dump_sql > /tmp/schema.sql"
    publish_schema_file('/tmp/schema.sql')
  end

  desc "Publish schema json"
  task :publish_json do
    sh "rake schema_docs:dump_json > /tmp/schema.json"
    publish_schema_file('/tmp/schema.json')
  end

  desc "Publish all schema"
  task :publish_all do
    sh "rake schema_docs:publish_json"
    sh "rake schema_docs:publish_json CURRENT=1"
    sh "rake schema_docs:publish_sql"
    sh "rake schema_docs:publish_sql CURRENT=1"
  end

  # Assume you have git+ssh://code.engineering.redhat.com/ESO_Performance.git
  # cloned in a nearby directory...
  desc "Update the errata.json in local perf book (No push to gerrit, do that yourself)"
  task :update_perf_book do
    sh "rake schema_docs:dump_json > ../ESO_Performance/scripts/db-schema.d/errata.json"
  end

end

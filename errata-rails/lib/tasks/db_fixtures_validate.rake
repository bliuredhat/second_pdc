namespace :db do
  namespace :fixtures do
    desc 'Validate fixtures and output any problems'
    task :validate => :environment do
      # Need to load all the model classes
      Rails.application.eager_load!

      table_class_map = Hash.new
      ActiveRecord::Base.descendants.each do |klass|
        table_class_map[klass.table_name] = klass
      end

      Dir["test/fixtures/*.yml"].sort.each do |fixture|
        begin
          klass = table_class_map[File.basename(fixture, ".yml")]
          raise "Could not find model class for #{fixture}" if klass.nil?
          klass.find(:all).each do |thing|
            begin
              unless thing.valid? then
                puts "#{fixture}: id ##{thing.id} is invalid:"
                thing.errors.full_messages.each do |msg|
                  puts " - #{msg}"
                end
              end
            rescue => e
              puts "#{fixture}: id ##{thing.id} raised exception: #{e.inspect}"
            end
          end
        rescue => e
          puts "#{fixture}: skipping: #{e.message}"
        end
      end
    end
  end
end

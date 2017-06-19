class AddTypeToTpsJob < ActiveRecord::Migration

  def up
    add_column :tpsjobs, :type, :string, :null => false

    jobs = %w[RhnTpsJob RhnQaTpsJob CdnTpsJob CdnQaTpsJob]
    jobs.each_index do |i|
      rhnqa = i % 2
      config = i <= 1 ? 'rhn' : 'cdn'

      say_with_time "Migrating rhnqa=#{rhnqa} TpsJobs to #{jobs[i]}" do
        execute <<-SQL
          UPDATE `tpsjobs` SET `type`= '#{jobs[i]}' WHERE rhnqa = #{rhnqa} AND config = '#{config}'
        SQL
      end
    end

    remove_column :tpsjobs, :config
    remove_column :tpsjobs, :rhnqa
  end

  def down
    add_column :tpsjobs, :config, :string,  :default => 'rhn', :null => false
    add_column :tpsjobs, :rhnqa,  :integer, :default => 0, :null => false

    jobs = %w[RhnTpsJob RhnQaTpsJob CdnTpsJob CdnQaTpsJob]
    jobs.each_index do |i|
      rhnqa = i % 2
      config = i <= 1 ? 'rhn' : 'cdn'

      say_with_time "Rolling back rhnqa=#{rhnqa} TpsJobs from #{jobs[i]}" do
        execute <<-SQL
          UPDATE `tpsjobs` SET `config` = '#{config}', `rhnqa` = #{rhnqa} WHERE type = '#{jobs[i]}'
        SQL
      end
    end

    remove_column :tpsjobs, :type
  end

end

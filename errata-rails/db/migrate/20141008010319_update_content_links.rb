class UpdateContentLinks < ActiveRecord::Migration
  def up
    open_content = Content.joins(:errata).where(:errata_main => {:status => State::OPEN_STATES})
    from = 'https://access.redhat.com/site/articles/'
    to = 'https://access.redhat.com/articles/'

    ActiveRecord::Base.transaction do
      %w[reference solution].each do |col|
        count = open_content.
          where("#{col} LIKE '%#{from}%'").
          update_all("#{col} = REPLACE(#{col}, '#{from}', '#{to}')")

        puts "Update #{col} #{from} -> #{to} : #{count}"
      end
    end
  end

  def down
    # The data transformation is not reversible.
    #
    # Thought about raising an ActiveRecord::IrreversibleMigration
    # here, but there doesn't seem to be any gain from doing that.
    # It makes the rollback command not work, unnecessarily.
    puts "NOTE: #{self.class} migration was not reversed - this is not a problem"
  end
end

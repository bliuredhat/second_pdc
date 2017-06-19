class CreateChannels < ActiveRecord::Migration
  def self.up
    create_table :channels do |t|
      t.string :name, :null => false
      t.string :type, :null => false
      t.integer :primary_channel_id
      t.integer :version_id, :null => false
      t.integer :arch_id, :null => false
      t.integer :product_version_id, :null => false
      t.string :cdn_path
      t.timestamps
    end
    
    # map = { }
    # clist = RhnChannel.find :all, :conditions => 'isdefault = 1'

    # clist.each do |c|
    #   map[c] = PrimaryChannel.create!(:name => c.rhn_channel,
    #                                   :variant => c.variant,
    #                                   :arch => c.arch,
    #                                   :product_version => c.product_version
    #                                   )
    # end

    # map.each_pair do |c, newc|
    #   BetaChannel.create!(:name => c.rhn_beta_channel,
    #                       :variant => c.variant,
    #                       :arch => c.arch,
    #                       :primary_channel => newc,
    #                       :product_version => c.product_version
    #                       ) if c.rhn_beta_channel?
      
    #   EusChannel.create!(:name => c.rhn_eus_channel,
    #                      :variant => c.variant,
    #                      :arch => c.arch,
    #                      :primary_channel => newc,
    #                      :product_version => c.product_version
    #                      ) if c.rhn_eus_channel?
      
    #   FastTrackChannel.create!(:name => c.rhn_fastrack_channel,
    #                            :variant => c.variant,
    #                            :arch => c.arch,
    #                            :primary_channel => newc,
    #                            :product_version => c.product_version
    #                            ) if c.rhn_fastrack_channel?
      
    #   ShadowChannel.create!(:name => c.rhn_shadow_channel,
    #                         :variant => c.variant,
    #                         :arch => c.arch,
    #                         :primary_channel => newc,
    #                         :product_version => c.product_version
    #                         ) if c.rhn_shadow_channel?
      
    # end
  end

  def self.down
    drop_table :channels
  end
end

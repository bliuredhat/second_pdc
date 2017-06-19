class BackupChannel < ActiveRecord::Base
  belongs_to :variant,
  :foreign_key => "version_id"
  belongs_to :arch
  belongs_to :product_version
  default_scope where("ctype != 'ShadowChannel'")
  default_scope includes(:variant, :arch, :product_version)
  def to_s
    "#{ctype} #{name} #{arch.name} #{variant.name}"
  end
end

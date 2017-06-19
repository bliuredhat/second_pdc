# Mixin concern to define certain attributes by name.
# For example, given a class like:
# class Foo < ActiveRecord::Base
#  belongs_to :variant
#  belongs_to :arch
#
# one can then do:
#   include NamedAttributes
#   named_attributes :arch, :variant
#
#  which will create the attr_accessors arch_name, arch_name=,
#  variant_name, and variant_name
#
#  This allows foo.update_attributes(:arch_name => 'x86_64', :variant_name => '6Client')
# 
# Useful for json api objects where we want to transparently handle name passing of objects.
module NamedAttributes
  extend ActiveSupport::Concern
  module ClassMethods
    def named_attributes(*attrs)
      attrs.each do |attr|
        define_method("#{attr}_name") do
          self.send(attr).name
        end
        
        define_method("#{attr}_name=") do |name|
          klass = attr.to_s.camelize.constantize
          self.send("#{attr}=", klass.find_by_name!(name))
        end
      end
    end
  end
end

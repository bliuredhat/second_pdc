module ModelDist
  extend ActiveSupport::Concern

  included do
    before_destroy :can_destroy?
  end

  module ClassMethods
    def human_attribute_name(attr, options = {})
      # Don't titleize 'CDN Repository/RHN Repository in the error hash'
      return attr if self.display_name == attr.to_s
      super
    end

    def short_display_name
      self.display_name.split.first
    end
  end

  def check_dist_links
    links = self.links
    if links.count > 1
      # exclude the link to itself
      link_list = links.where("variant_id != ?", variant).collect{|l| l.variant.name}.join(', ')
      errors.add("#{self.class.display_name}", "'#{name}' is attached to multiple variants: #{link_list}.")
    end
  end

  def check_associations
    self.class.reflect_on_all_associations(:has_many).each do |relation|
      options = relation.options
      next unless options.has_key?(:dependent) && options[:dependent] == :restrict

      related = relation.name
      if send(related).size > 0
        errors.add("#{self.class.display_name}", "'#{name}' is depending by #{related.to_s.underscore.humanize.downcase}.")
      end
    end
  end

  def can_destroy?
    # check whether the dist is attached to other variants or not
    check_dist_links
    # check whether the dist has any other dependents or not, such as tps jobs
    check_associations
    return errors.empty?
  end
end

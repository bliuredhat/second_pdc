class BrewRpmNamePrefix < ActiveRecord::Base
  validates :text, :presence => true, :uniqueness => { :scope => :product_id }
  belongs_to :product

  def self.products_with_prefixes
    select("DISTINCT product_id").map(&:product)
  end

  def prefix_regex
    /^#{Regexp.escape(text)}-/
  end

  def stripped_from(name)
    name.sub(prefix_regex, '')
  end

  def matches(name)
    name.match(prefix_regex)
  end

  def self.strip_using_list_of_prefixes(prefix_list, name)
    prefix_list.sort_by(&:text).each do |prefix|
      return prefix.stripped_from(name) if prefix.matches(name)
    end
    name
  end

end

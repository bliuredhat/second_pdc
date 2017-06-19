# Base class for a FormObject for linking or unlinking a set of objects to an advisory.
# Ensures each link is valid and ensures that all links are set/unset in the same transaction.
class LinkSetBase
  include FormObject

  validate :validate_links

  def initialize(options)
    [:new_link, :link_type, :targets, :errata].each do |sym|
      value = options[sym] || raise(ArgumentError, "missing #{sym}")
      self.instance_variable_set('@' + sym.to_s, value)
    end
    @operation = options[:operation] || 'added'
    @persist_links = options[:persist_links] || lambda do |targets|
      targets.each {|t| @new_link.call(t, @errata).save! }
      @errata.invalidate_docs_maybe!(:reason => "#{@link_type}s added")
    end
  end

  def comment_class
    Comment
  end

  def validate_links
    return if @targets.empty?
    with_errors = @targets.collect{|t| @new_link.call(t, @errata)}.reject {|f| f.valid? }
    with_errors.each {|f| errors.add(:base, f.errors.full_messages)}
  end

  def persist!
    return if @targets.empty?
    msg = ["The following #{@link_type}s have been #{@operation}:"].concat(@targets.collect {|t| "#{@link_type} #{t.display_id} - #{t.summary}" }).join("\n")
    ActiveRecord::Base.transaction do
      @persist_links.call(@targets)
      @errata.comments << comment_class.new(text: "\n__div_bug_states_separator\n#{msg}\n__end_div\n")
    end
  end
end

# == Schema Information
#
# Table name: errata_content
#
#  id              :integer       not null, primary key
#  errata_id       :integer       not null
#  topic           :string(4000)  not null
#  description     :text          not null
#  solution        :text          not null
#  keywords        :string(4000)  not null
#  obsoletes       :string(4000)
#  cve             :string(4000)
#  packages        :text
#  multilib        :text
#  crossref        :string(4000)
#  reference       :string(4000)
#  how_to_test     :text
#  doc_reviewer_id :integer       default(1), not null
#  updated_at      :datetime      not null
#  revision_count  :integer       default(1), not null
#

class Content < ActiveRecord::Base
  self.table_name = "errata_content"
  validates_presence_of :topic, :solution, :description
  validate :description_wrapped_length_ok

  scope :with_cve, where("cve is not null and cve != ''")

  belongs_to :errata,
    :foreign_key => 'errata_id'

  belongs_to :doc_reviewer,
    :class_name => "User",
    :foreign_key => 'doc_reviewer_id'

  before_create do
    self.obsoletes ||= ''
    self.reference ||= ''
    self.crossref ||= ''
    self.keywords ||= ''
    self.doc_reviewer ||= User.default_docs_user
    unless self.errata.is_security?
      self.cve = ''
    end
  end

  before_save do
    clean_whitespace

    if self.errata.can_have_cve? && self.cve.present?
      # Sort the cves and normalize whitespace
      self.cve = self.cve.split(/[\s,]+/).reject(&:blank?).sort.uniq.join(' ')
    else
      # Clear CVE field, it is either not applicable or should be normalized to ''
      self.cve = ''
    end

    # Add or remove impact links as required
    self.reference = self.massage_reference

    # Keep data clean, make sure there's nothing unexpected in the text_only_cpe field.
    # (Might be relevant if the advisory's type gets changed or it starts as text_only then
    # gets changed to non-text only).
    self.text_only_cpe = nil unless self.errata.can_have_text_only_cpe? && self.text_only_cpe.try(:strip).present?
  end

  before_validation do
    clean_whitespace
  end

  # Fix line breaks and normalize blank lines for main content fields
  def clean_whitespace
    [:topic,:description,:solution,:reference,:text_only_cpe].each do |key|
      write_attribute(key, read_attribute(key).gsub("\r\n","\n").gsub(/\n{3,}/,"\n\n").strip) if read_attribute(key)
    end
  end

  # The args here are only needed when this is called from ErrataController#preview.
  # Without this the preview would display the wrong reference text if the user is
  # changing the type or the impact, (even though it would get fixed when advisory is saved).
  def massage_reference(original_reference=nil, errata_type=nil, security_impact=nil)
    original_reference ||= self.reference
    errata_type        ||= self.errata.errata_type
    security_impact    ||= self.errata.security_impact

    if errata_type == 'RHSA' || errata_type == 'PdcRHSA'
      # Give it the right impact link
      TextWithImpactLink.new(original_reference).ensure_link(security_impact).to_s
    else
      # Remove them all
      TextWithImpactLink.new(original_reference).strip_links.to_s
    end
  end

  def docs_unassigned?
    self.doc_reviewer_id == User.default_docs_user.id
  end

  def public_cpe_data_changed?
    return false unless errata.status_is? :SHIPPED_LIVE
    cve_changed? || text_only_cpe_changed?
  end

  def description_wrapped_length_ok
    if description.length > 4000
      errors.add(:description, "length is #{description.length} which is longer than the 4000 character limit.")
      return
    end
    escaped_length = description.errata_word_wrap.length
    if escaped_length > 4000
      errors.add(:description, "length after formatting and wrapping is #{escaped_length} which is longer than the 4000 character limit. (Unformatted length is #{description.length}).")
    end
  end

end

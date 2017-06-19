class CdnRepoPackageTag < ActiveRecord::Base
  include Audited

  belongs_to :cdn_repo_package
  belongs_to :who,
    :class_name => "User",
    :foreign_key => "who_id"

  belongs_to :variant

  validates_uniqueness_of :tag_template, :scope => :cdn_repo_package_id,
    :message => 'is already defined for this package in this repository'

  validate :validate_tag_template

  # All tags that apply to given variant, including "any variant" tags
  scope :for_variant, lambda { |variant| where(:variant_id => [variant, nil]) }

  MAX_TAG_TEMPLATE_LENGTH = 80
  MIN_TAG_TEMPLATE_LENGTH = 2
  VALID_TAG_REGEX = /^[\w\.-]*$/

  #
  # Returns actual tag for a given build, replacing placeholders with
  # attributes from build.
  # Supported placeholders are {{version}} and {{release}}
  #
  # An optional number of dotted number groups can be specified,
  # for example: {{version(3)}} would return "31.4.15" if the build's
  # version string was "v31.4.15.9.2".
  #
  def tag_for_build(build=nil)
    replacements = {
      "version" => lambda { |build| build.try(:version) || '' },
      "release" => lambda { |build| build.try(:release) || '' },
    }

    tag_template.gsub(/\{\{\s*(\w+)\s*(?:\((\d+)\))?\s*\}\}/i) do |match|
      # Get attribute values for placeholder from build
      str = replacements[$1.downcase].try(:call, build) || match
      # If specified, extract given number of dotted digit groups
      $2 ? str.slice(Regexp.new('\d+(?:\.\d+){0,' + "#{$2.to_i-1}}")) : str
    end
  end

  def validate_tag_template
    errors.add(:tag_template, "is too long") if tag_template.length > MAX_TAG_TEMPLATE_LENGTH
    errors.add(:tag_template, "must be at least 2 characters") if tag_template.length < MIN_TAG_TEMPLATE_LENGTH
    errors.add(:tag_template, "must contain only characters [A-Za-z0-9_.-]") unless tag_for_build =~ VALID_TAG_REGEX
  end
end

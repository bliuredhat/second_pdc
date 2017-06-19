#
# See bug 738531.
#
# Want to use this to add and remove links from the
# errata.content.references text field.
#
# https://access.redhat.com/security/updates/classification/#low
#
# (It seems a bit crazy that we need to store those
# links actually in the references field. It would be more sensible
# to auto append them to the manually entered references text. But
# never mind that now.. Going to try for a low risk quick fix that
# is easily testable).
#
#
class TextWithImpactLink < String
  IMPACT_URL     = 'https://access.redhat.com/security/updates/classification/'
  IMPACT_URL_OLD = 'http://www.redhat.com/security/updates/classification/'

  LINK_PREFIXES = [IMPACT_URL, IMPACT_URL_OLD]
  IMPACTS = SecurityErrata::IMPACTS

  # Should match links like this and eat the whitespace after but not before.
  # https://access.redhat.com/security/updates/classification/#low
  # http://www.redhat.com/security/updates/classification/#critical
  LINK_REGEX = /(?:#{LINK_PREFIXES.map{ |p| Regexp.escape(p) }.join('|')})#(?:#{IMPACTS.map(&:downcase).join('|')})\s*/m

  # Want to be able to take a nil
  # (String.new(nil) will throw an exception otherwise)
  def initialize(string=nil)
    super(string||'')
  end

  def strip_links
    self.gsub(LINK_REGEX,'')
  end

  def links
    self.scan(LINK_REGEX).map(&:strip)
  end

  def has_link?(impact=nil)
    impact ? links.include?(TextWithImpactLink.make_link(impact)) : links.any?
  end

  def ensure_link(impact)
    has_link?(impact) ? self : self.strip_links.add_link(impact)
  end

  def self.make_link(impact)
    raise "Invalid impact '#{impact}'!" unless IMPACTS.include?(impact)
    "#{IMPACT_URL}##{impact.downcase}"
  end

  def to_s
    String.new(self)
  end

  protected

  def add_link(impact)
    self.sub(/^/, "#{TextWithImpactLink.make_link(impact)}\n")
  end

end

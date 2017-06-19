class String
  # http://blog.macromates.com/2006/wrapping-text-with-regular-expressions/
  def wrap_text(col = 75)
    self.gsub(/(.{1,#{col}})( +|$)\n?|(.{#{col}})/,
              "\\1\\3\n").strip
  end

  def wrap_and_indent_bulleted(col = 75, indent = 2)
    "* #{self}".wrap_text(col - indent).gsub(/\n/,"\n#{' ' * indent}")
  end

  def errata_word_wrap(width=80)
    self.
      gsub(/&#010;/, "\n").
      gsub(/(.{1,#{width}})( +|$\n?)/, "\\1\\3\n").
      gsub(/\"/, "&quot;").
      gsub(/>/, "&gt;").
      gsub(/</, "&lt;")
  end

  def full_stop
    text = self.strip
    text =~ /[\.\!\?>]$/ ? text : "#{text}."
  end
end

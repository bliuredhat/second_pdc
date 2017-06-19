require 'rubygems'
require 'diff/lcs'
require 'diff/lcs/hunk'

# Diffs two strings using diff-lcs, provides output in unified diff format by default
# From Recipie 6.10 of Ruby Cookbook
# http://www.crummy.com/writing/RubyCookbook/downloads/Ruby%20Cookbook%20Source.zip
#
def diff_as_string(data_old, data_new, format=:unified, context_lines=3)

  data_old = data_old.split(/\n/).map! { |e| e.chomp }
  data_new = data_new.split(/\n/).map! { |e| e.chomp }

  output = ""
  diffs = Diff::LCS.diff(data_old, data_new)
  return output if diffs.empty?
  oldhunk = hunk = nil
  file_length_difference = 0
  diffs.each do |piece|
    begin
      hunk = Diff::LCS::Hunk.new(data_old, data_new, piece, context_lines,
                                 file_length_difference)
      file_length_difference = hunk.file_length_difference
      next unless oldhunk

      # Hunks may overlap, which is why we need to be careful when our
      # diff includes lines of context. Otherwise, we might print
      # redundant lines.
      if (context_lines > 0) and hunk.overlaps?(oldhunk)
        hunk.unshift(oldhunk)
      else
        output << oldhunk.diff(format)
      end
    ensure
      oldhunk = hunk
      output << "\n"
    end
  end

  #Handle the last remaining hunk
  output << oldhunk.diff(format) << "\n"
end

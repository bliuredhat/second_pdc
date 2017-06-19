# Override schema_dumper to get rid of pretty formatting.
#
# The pretty formatting makes schema.rb look nicer but makes diffs look messier,
# as modifying a single column can change the whitespace on every other line in
# that table.
#
# This file doesn't contain any rake tasks.  The code lives in lib/tasks/*.rake
# because it should be loaded whenever rake is invoked.
require 'active_record/schema_dumper'

module ActiveRecord
  class SchemaDumper
    private

    def table_with_simplified_whitespace(table, stream, &block)
      strio = StringIO.new
      begin
        return table_without_simplified_whitespace(table, strio, &block)
      ensure
        stream.write(ActiveRecord::SchemaDumper.simplify_ws(strio.string))
      end
    end

    unless ENV['PRETTY_SCHEMA'] == '1'
      alias_method_chain :table, :simplified_whitespace
    end

    # Undo the extra whitespace added by schema_dumper to line up the columns
    # and attributes.
    def self.simplify_ws(tbl)
      tbl.
        # :a => 'b',   :c => d
        gsub(/,\s+:/, ', :').
        # t.coltype   "foo"
        gsub(/^( *[^ ]+) +"/, '\1 "')
    end
  end
end

module SchemaPlus
  module ActiveRecord
    module SchemaDumper
      # Fix unsorted indexes and foreign keys, which means these can
      # jump around for no reason.
      #
      # This was already fixed upstream, see
      # https://github.com/SchemaPlus/schema_plus/commit/fc4aa868bcf0f148c4a452b7a1b31af48869f612
      # , but in a much newer version of schema_plus than we're using
      # which already dropped ruby 1.8 support.

      def dump_indexes_with_sort(*args, &block)
        _sort_lines dump_indexes_without_sort(*args, &block)
      end

      def dump_foreign_keys_with_sort(*args, &block)
        _sort_lines dump_foreign_keys_without_sort(*args, &block)
      end

      def _sort_lines(text)
        return text if text.blank?
        text.split("\n").sort.join("\n") + "\n"
      end

      alias_method_chain :dump_indexes, :sort
      alias_method_chain :dump_foreign_keys, :sort
    end
  end
end

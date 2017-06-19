# :simplecov_exclude:
#
# Needed a good way to define the top level structure of our
# books without lots of xml clutter so why not erb.
#
# Use this to produces the main book file, Main.xml from the
# erb template, Main.erb.
#
# See publican.rake and the three publican_docs/Book_Name/Main.erb
# files.
#
#
module DocbookErb
  module Helpers
    #
    # If you add :draft=>true to the include and part methods
    # it will hide the content unless ENV['DRAFT'] is set.
    #
    # Similarly add non_draft_only=>true to hide the content if
    # ENV['DRAFT'] is set..
    #
    def draft_is_set?
      ENV['DRAFT'].present? && ENV['DRAFT'] != '0'
    end
    def hide_draft_content?(opts)
      opts[:draft] && !draft_is_set?
    end
    def hide_non_draft_content?(opts)
      opts[:non_draft_only] && draft_is_set?
    end
    def hide_content?(opts)
      hide_draft_content?(opts) || hide_non_draft_content?(opts)
    end

    #
    # The content will be included by ERB prior to publican running.
    # (Note: it doesn't parse the included content, just slaps it in as is).
    #
    def include_generated(file_name, opts={})
      File.read("#{@md_output_dir}/#{file_name}") unless hide_content?(opts)
    end

    #
    # Locate and sort all the release note files
    #
    def find_all_generated_release_notes
      Dir["#{File.dirname(@erb_file)}/markdown/Rel_Notes_*.md*"]. # some are .md, some are .md.erb
        map { |f| File.basename(f).split('.').first }. # eg Rel_Notes_3_11_6
        sort_by { |f| f.split('_').map(&:to_i) }. # eg [0, 0, 3, 11, 6]
        reverse # newest first
    end

    #
    # Include all the release note files
    #
    def include_all_generated_release_note_files
      find_all_generated_release_notes.
        map{ |f| include_generated "#{f}.xml" }.
        join("\n")
    end

    #
    # Will be processed by publican using xml.
    # The included file must be valid xml and the path must
    # be findable when publican runs.
    #
    def xi_include(file_name, opts={})
      %{<xi:include href="#{file_name}" xmlns:xi="http://www.w3.org/2001/XInclude"></xi:include>} unless hide_content?(opts)
    end

    #
    # A helper for creating a 'part'.
    # See Main.erb files for usage.
    #
    def part(part_label, part_title, part_intro, opts={})
      return if hide_content?(opts)

      concat_output <<EOT
  <part label="#{part_label}">
    <title>#{part_title}</title>
    <partintro>
      <para>#{part_intro}</para>
    </partintro>
EOT

      yield

      concat_output <<EOT
  </part>
EOT
    end

    #
    # A helper for creating a chapter (or a section)
    #
    def chapter(elem_id, elem_title, opts={})
      elem_name = opts[:elem_name] || 'chapter'

      concat_output <<EOT
    <#{elem_name} id="#{elem_id}">
      <title>#{elem_title}</title>
EOT

      yield

      concat_output <<EOT
    </#{elem_name}>
EOT
    end

    #
    # A helper for creating a section.
    # (Sections have the same structure as chapters, just a different element name)
    #
    def section(elem_id, elem_title)
      section(elem_id, elem_title, :elem_name=>'section')
    end

    #
    # A helper for making a book.
    # See Main.erb files for usage.
    #
    # (Maybe this could be a layout of some kind,
    # though that might be overdoing it..)
    #
    def book(name='Main')
      concat_output <<EOT
<?xml version='1.0' encoding='utf-8' ?>
<!-- *** DO NOT EDIT. GENERATED FROM #{@erb_file}. *** -->
<!DOCTYPE book PUBLIC "-//OASIS//DTD DocBook XML V4.5//EN" "http://www.oasis-open.org/docbook/xml/4.5/docbookx.dtd" [
<!ENTITY % BOOK_ENTITIES SYSTEM "#{name}.ent">
%BOOK_ENTITIES;
]>
<book>
EOT

      yield

      concat_output <<EOT
</book>
EOT
    end

    #
    # Just a helper to conditionally show or hide a block of content.
    # Using this in User_Guide/Main.erb with :non_draft_only => true.
    #
    def show_maybe(opts={})
      return if hide_content?(opts)
      yield
    end

  end
end

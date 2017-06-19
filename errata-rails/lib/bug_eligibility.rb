# -*- coding: utf-8 -*-
# This checklist is used to validate bugs against various rules imposed by releases.
#
# == Example:
# * test the given bug, with the given release on every available check
#     BugEligibility::CheckList.new(bug, :release=>errata.release).result_list.each do |result, message, title|
#       errors.add("Bug ##{bug.bug_id}", message) if !result
#     end
module BugEligibility

  class BugCheck < ::CheckList::Check
    include CheckList::AdvisoryLinkHelper

    setup do
      @release ||= @bug.guess_release_from_flag
      @package = @bug.package
    end
  end

  class CheckList < ::CheckList::List

    class CorrectFlags < BugCheck
      order 1
      title 'Correct flags?'
      pass { @release && @release.has_correct_flags?(@bug) }
      pass_message { "All required flags are present." }

      fail_message do
        return "Can't find a release flag (or can't find release for release flag). Perhaps a release needs to be created." unless @release
        # This might need review since we do now use Y-stream create advisory mechanism for FastTrack advisories
        fast_message = " and must not have the 'fast' flag (unless you are creating a FastTrack advisory)" if !@release.is_fasttrack? && @bug.has_flag?('fast')
        "The bug must have the following acked flags: #{@release.blocker_flags.join(", ")}#{fast_message}."
      end

      note "Note: There are exceptions to this rule related to the 'blocker' &amp; 'exception' flags, &amp; on the 'Security' keyword."
    end

    class CorrectBugState < BugCheck
      order 2
      title 'Correct status?'
      pass { valid_bug_states.include?(@bug.bug_status) }
      pass_message { "The bug's status is correct. (One of #{valid_bug_states.join(', ')})" }
      fail_message { "Requires status #{valid_bug_states.join(', ')}. The bug is currently #{@bug.bug_status}." }
      note "Note: There are some exceptions to this rule, for example security advisories can bypass this requirement."

      def valid_bug_states
        return ['ON_QA', 'VERIFIED'] if @bug.keywords =~ /TestOnly/
        @release.try(:valid_bug_states) || %w[VERIFIED MODIFIED]
      end
    end

    class PartOfAdvisory < BugCheck
      order 3
      title 'Not filed?'
      pass do
        if is_rhsa?
           true
        else
          FiledBug.where(bug_id: @bug, errata_id: advisory_scope).none?
        end
      end
      pass_message { is_rhsa? \
        ? "This rule is not applicable to RHSA." \
        : "The bug is not filed on any existing advisory."
      }
      fail_message do
        advisories = FiledBug.where(bug_id: @bug, errata_id: advisory_scope).map(&:errata)
        "The bug is filed already in #{advisories.map{|e|advisory_link(e)}.join(", ")}."
      end

      def is_rhsa?
        @errata && @errata.is_security?
      end

      def advisory_scope
        scope = if @errata.nil?
                  :scoped
                elsif @errata.is_pdc?
                  :only_pdc
                else
                  :only_legacy
                end
        Errata.send(scope)
      end
    end

    # Ensure bug is in approved component list.
    # (Applies to QuarterlyUpdate releases only).
    class PartOfComponent < BugCheck
      order 4
      title 'Approved component?'

      pass do
        return false unless @release
        return true unless @release.supports_component_acl?
        available_components.where(:package_id => @package).any?
      end

      pass_message do
        return "Not needed for release type #{@release.class.name}" unless @release.supports_component_acl?
        "#{@package.name} is on the approved component list for #{@release.name}."
      end

      fail_message do
        if @release.blank?
          "No valid release found hence can't check approved components."
        elsif @release.approved_components.empty?
          "The approved component list for #{@release.name} is currently empty, hence this
          (or any) bug can't be added to release #{@release.name}."
        elsif adv = unavailable_components.where(:package_id => @package).first
          # Uncertain whether @errata or adv.errata should be reported if both
          # are present.  So report both of 'em in that case.
          ["#{@package.name} is already covered in the release by",
           ["#{advisory_link(@errata) if @errata}",
            "#{advisory_link(adv.errata)}"
           ].reject(&:blank?).join(' and/or ')
          ].join(' ')
        else
        "#{@package.name} is NOT on the approved component list for #{@release.name}.
          Please contact Program Management and have the component added to the ACL. Contact information for
          the individual products and their releases is available on the #{product_pages_link}."
        end
      end

      def available_components
        rc = @release.release_components
        if @release.allow_pkg_dupes?
          # doesn't matter if an advisory is already filed for this component
          rc
        elsif @errata && !@errata.new_record?
          # component must be covered by no advisory OR by this advisory
          rc.where('errata_id is null or errata_id = ?', @errata)
        else
          # component must be covered by no advisory
          rc.uncovered
        end
      end

      def unavailable_components
        rc = @release.release_components
        if @release.allow_pkg_dupes?
          # if dupes allowed, components are always available
          rc = rc.where('1 = 0')
        else
          rc = rc.where('errata_id is not null')
          if @errata && !@errata.new_record?
            rc = rc.where('errata_id != ?', @errata)
          end
          rc
        end
      end

      # Because links get escaped in error_messages_for. (Todo: This is insane, fixme!)
      def product_pages_link
        return "Product Pages (https://engineering.redhat.com/pp/)" unless @enable_links
        link_to('Product Pages', 'https://engineering.redhat.com/pp/')
      end
    end

    class AdvisoryForComponent < BugCheck
      order 5
      title 'No existing advisory<br/>for component in release?'

      pass do
        return true if @release && (@release.allow_pkg_dupes? || !@release.is_ystream?)
        @release && !existing_advisory_for_component
      end

      pass_message do
        if @release && @release.allow_pkg_dupes?
          "Release #{@release.name} allows more than one advisory for a single package."
        else
          "No existing advisory for package '#{@package.name}' in release '#{@release.name}'."
        end
      end

      fail_message do
        if @errata
          "Bug cannot be added to advisory, since it is for component #{@bug.component}. Only #{@errata.packages.map(&:name).join(', ')} allowed."
        elsif @release
          "This bug should be added to the existing advisory #{advisory_link(existing_advisory_for_component)},"\
          " since it already covers the #{@bug.component} component."
        else
          "No valid release found hence can't check for existing advisory."
        end
      end

      note "Note: This requirement applies to Y-stream releases only, and may be omitted for certain releases."

      def existing_advisory_for_component
        if @errata
          return false if @errata.packages.empty? || @errata.packages.include?(@package)
        end
        @release.errata.detect { |e| e.packages.include?(@package) }
      end
    end

  end
end

module Tps
  class DistReposGrouping
    def initialize(dist_repos)
      @group_list = Hash.new{|h,k| h[k] = {:parent => nil, :children => Set.new}}
      self.concat(dist_repos)
    end

    def append(dist_repo)
      return self unless dist_repo.can_be_used_for_tps?

      # Group the channels/repos by rhel_variant, arch and dist repo type
      # is better than using parent channel for grouping, because not all
      # sub-channels will have base channel set.
      # For example, a longlife channel is been set in 6Server-HighAvailability-6.5.z,
      # but no longlife channel is been set in 6Server.6.5.z
      group_key = {
        :rhel_variant => dist_repo.variant.rhel_variant.name,
        :arch => dist_repo.arch.name,
        :type => dist_repo.type,
      }

      parent = dist_repo.get_parent
      if dist_repo == parent
        @group_list[group_key][:parent] = parent
      else
        @group_list[group_key][:children] << dist_repo
      end
      return self
    end

    def concat(dist_repos)
      dist_repos.each do |dist_repo|
        self.append(dist_repo)
      end
      return self
    end

    def group_by_parent
      all_dist_repos = Set.new
      @group_list.each_pair do |group_key, group|
        # Use parent channel/repo to schedule TPS job if it exists
        # in the list
        if group[:parent]
          all_dist_repos << group[:parent]
          next
        end

        # Use parent channel/repo to schedule TPS job if:
        # - child channels/repos have parent and
        # - there are more than 1 children with the same parent and
        # - their parent is enabled for TPS job
        #
        # Otherwise, schedule separate TPS jobs for each child
        parent = group[:children].first.get_parent
        children = group[:children]

        if children.length > 1
          if parent.nil?
            # the channel/repo is an orphan
            log_message = "Could not find parent for #{children.map(&:name).join(',')}"\
              " for grouping."
          elsif !parent.can_be_used_for_tps?
            log_message = "Could not group #{children.map(&:name).join(',')} together"\
              " because '#{parent.name}' parent is not set up to run TPS Job"\
              " ('use for TPS scheduling?' flag is not checked)."
          else
            all_dist_repos << parent
            next
          end
        end

        Rails.logger.warn(log_message) unless log_message.nil?
        all_dist_repos.merge(children)
      end

      return all_dist_repos
    end
  end
end
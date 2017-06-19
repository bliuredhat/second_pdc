module Push
  module Pub
    def self.is_valid_push_target?(name)
      push_targets.keys.include? name.to_sym
    end

    def self.valid_push_targets
      push_targets.keys
    end

    def self.pub_target(push_target_name)
      return nil unless is_valid_push_target? push_target_name
      push_targets[push_target_name][:target]
    end

    def self.push_targets
      Settings.pub_push_targets.deep_symbolize_keys
    end
  end
end

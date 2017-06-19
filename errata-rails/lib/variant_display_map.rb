# Data structure to assist in the display of variant tables.
#
module VariantDisplayMap

  # Might look weird, but this allows the code to be hot-reloaded.
  # Without this pattern, loading this file more than once will crash since
  # Struct.new will return a new class object each time.
  @ChannelsAndReposStruct ||= Struct.new(:channels, :cdn_repos)
  class ChannelsAndRepos < @ChannelsAndReposStruct
    def initialize
      channels  = VariantDistReposMap.new(:channel)
      cdn_repos = VariantDistReposMap.new(:cdn_repo)
      super(channels, cdn_repos)
    end
  end

  @VariantDistReposStruct ||= Struct.new(:type)
  class VariantDistReposMap < @VariantDistReposStruct
    def initialize(type)
      super(type)
      @map = Hash.new{|hash,key| hash[key] = [] }
    end

    def for_product_version(pv)
      # make sure any variants with no channels/repos are also created.
      pv.variants.each { |v| @map[v] }
      for_obj(pv)
    end

    def for_variant(v)
      @map[v]
      for_obj(v)
    end

    def for_obj(obj)
      obj.
        send("#{type}_links").
        includes(:variant).
        each { |x| self << x }
      self
    end

    def <<(dist_repo_link)
      @map[dist_repo_link.variant] << dist_repo_link.dist
      self
    end

    def sort
      @map.sort_by{|v,r| v.name}.each_with_object([]) do |(v, r), list|
        list << [ v, self.send("#{type}_sort", r) ]
      end
    end

    private

    def channel_sort(list)
      list.sort_by{ |c| [c.short_type, c.arch, c.name, c.product_version.name] }
    end

    def cdn_repo_sort(list)
      list.sort_by{ |r| [r.short_release_type, r.arch, r.name, r.short_type,  r.product_version.name] }
    end
  end

  # VariantDisplayMap.for_product_version(pv) provides a tree containing
  # variants, channels and cdn repos attached to variants grouped by dist type,
  # similar to the following structure:
  #
  # {
  #    channels => {
  #      variant1 => [c1, c2, c3...],
  #      variant2 => ...,
  #    },
  #    cdn_repos => {
  #      variant1 => [r1, r2, r3...],
  #      variant2 => ...,
  #    }
  # }
  #
  def self.for_obj(obj)
    map = ChannelsAndRepos.new
    [:channels, :cdn_repos].each do |type|
      map.send(type).send("for_#{obj.class.name.underscore}", obj)
    end
    map
  end

  def self.for_product_version(pv)
    for_obj(pv)
  end

  # Like for_product_version, but slices the part of the tree for the
  # specified variant.
  def self.for_variant(v)
    for_obj(v)
  end
end

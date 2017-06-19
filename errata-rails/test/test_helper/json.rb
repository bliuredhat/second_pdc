class ActiveSupport::TestCase

  # Given a valid JSON string, returns a transformed JSON string where:
  #
  #  - objects are sorted by key
  #  - output is pretty-printed
  #
  # Designed for use with with_baselines.
  def canonicalize_json(json, opts = {})
    obj = JSON.parse(json, :object_class => TestHelperJson::SortedHash)

    # Allow for arbitrary transformation after parsing and before
    # dumping JSON, e.g. to filter out certain elements.
    if block = opts[:transform]
      obj = block.call(obj)
    end

    # Annoyingly we have to pull in a separate JSON gem just for this.
    #
    # Normally, we have access to json/ext and json/pure, with
    # json/ext used by default.  However:
    #
    # - json/ext is unable to pretty-print Hash subclasses, because it
    #   specifically checks if an object's class is Hash, rather than
    #   checking if an object is a kind_of? Hash.
    #   https://github.com/flori/json/blob/v1.8.0/ext/json/ext/generator/generator.c#L828
    #
    # - we can't temporarily switch to json/pure just for this - if
    #   you loaded json/ext once, you have to use it for the rest of
    #   the process lifetime.  See https://github.com/flori/json/issues/186
    #
    # - we shouldn't switch production to json/pure just to make the
    #   tests work, since it's slower
    #
    # - we shouldn't switch the test suite to use a different json
    #   implementation than used in production
    #
    # So we use yajl through multijson, which gives the results we
    # need, and unlike json/ext or json/pure, doesn't permanently
    # install to_json instance methods on objects or otherwise mess with the environment.
    #
    MultiJson.with_adapter(:yajl) do
      MultiJson.dump(obj, :pretty => true)
    end
  end

  # Like canonicalize_json, but includes the HTTP response status as a leading comment.
  # Use it to test JSON response body and code together.
  def formatted_json_response(opts={})
    [
      "# HTTP #{response.status}",
      canonicalize_json(response.body, opts),
      '' # make baseline file end with newline
    ].join("\n")
  end
end

module TestHelperJson
  # A hash which maintains sorted order of keys, for JSON canonicalization.
  # NOT a general purpose sorted hash - only reimplements the methods needed
  # for the JSON canonicalization.
  class SortedHash < ActiveSupport::OrderedHash
    def []=(key, val)
      new_key = !self.include?(key)

      out = super

      if new_key
        _rebuild
      end

      out
    end

    # rebuild self, ensuring keys are in sorted order
    def _rebuild
      replacement = ActiveSupport::OrderedHash.new
      self.keys.sort.each do |key|
        replacement[key] = self[key]
      end

      self.replace(replacement)
    end
  end
end

#
# Rather than proxy the request to the rss feed from our announcement blog
# might as well cache it a bit so we aren't fetching it every time.
#
# Doing this so we don't have to deal with cross-domain issues or kerberos
# auth when fetching the rss for the 'News' menu.
#
# See a/c/news_feed_controller.rb
#
class RssFeedCachedFetch
  DEFAULT_CACHE_PERIOD = 60*60 # an hour

  def initialize(url, cache_file, cache_period=DEFAULT_CACHE_PERIOD)
    @url = url
    @cache_file = cache_file
    @cache_period = cache_period
    @curl = ::Curl::Easy.new(@url)

    # (Just in case we need kerberos again some day)
    #@curl = ::Curl::Easy.new(@url) do |curl|
    #  curl.http_auth_types = ::Curl::CURLAUTH_GSSNEGOTIATE
    #  curl.userpwd = ':'
    #end
  end

  def fetch
    # Whatever the error, never die here
    @curl.perform rescue nil
    @curl.body_str if @curl.response_code == 200
  end

  def update_cache
    if content = fetch
      content.force_encoding('utf-8')
      File.open(@cache_file, 'w') { |file| file.write(content) }
    else
      FileUtils.touch(@cache_file) # try again later
    end
  end

  def read_cache
    File.read(@cache_file)
  end

  def cache_stale?
    !File.exist?(@cache_file) || Time.now > File.ctime(@cache_file) + @cache_period
  end

  def get(opts={})
    update_cache if opts[:force_refresh] || cache_stale?
    read_cache
  end
end

#if __FILE__ == $0
#  # (For debugging. Todo: Move this into a unit test)
#  %w[rubygems curb fileutils].each{ |r| require r }
#  puts RssFeedCachedFetch.new('https://blogs.corp.redhat.com/erratatool/feed/', '/tmp/foo.xml').get(:force_refresh=>true)
#end

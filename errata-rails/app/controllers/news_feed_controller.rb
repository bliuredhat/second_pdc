# (Note: Even though this is a "no auth" controller I didn't move it to
# the noauth directory because I don't want it to need a custom route).

class NewsFeedController < Noauth::ControllerBase

  # There's no great reason why it should be in this
  # directory, but it seems like an okay place to keep it.
  RSS_CACHE_PATH = "#{Rails.public_path}/news.rss"

  CACHE_PERIOD = 2.hours

  def rss
    # set Cache-Control header so browser knows to cache it
    expires_in CACHE_PERIOD, :public => true
    render :text => rss_feed_content, :content_type => 'text/xml'
  end

  private

  def rss_feed_content
    RssFeedCachedFetch.new(Settings.news_rss_url, RSS_CACHE_PATH, CACHE_PERIOD).get
  end

end

namespace :news_feed do

  #
  # Normally it should update within the hour. But if you want to make
  # it update right away you can run this.
  #
  desc "force rss update now"
  task :force_update => :environment do
    local_file = NewsFeedController::RSS_CACHE_PATH
    rss_url = Settings.news_rss_url
    RssFeedCachedFetch.new(rss_url, local_file).get(:force_refresh => true)
    puts "Updated: #{local_file}"
    puts "From URL: #{rss_url}"
    puts `head #{local_file}`
  end

end

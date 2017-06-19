//
// Dynamically add news items to the news menu
// (and indicate when there are new items).
// Uses jquery.jfeed and jquery.cookie plugins.
//
;(function($){

  $(document).ready(function() {

    // Remember the time user clicked 'News'
    $('#news_menu').click(function(){
      $.cookie('last_viewed_news', (new Date()).valueOf(), { expires: 10000/*days*/, path: '/' });
    });

    // Read the feed and add the news menu items
    $('#rss_container').find('.wait-spinner').show();
    $.getFeed({
      url: '/news_feed/rss',

      success: function(feed) {
        // when public/news.rss is empty, it causes the spinner set on body
        // by other XHR calls to remain displayed even when the XHR is
        // successfully completed. see: ajax_spinner.js

        $('#rss_container').find('.wait-spinner').hide();
        if (feed.items == null) {
          $('#rss_container').prepend( '<li> <a class="unread"> No news feeds </a> </li>');
          return;
        }

        var last_viewed_cookie = $.cookie('last_viewed_news');
        var last_viewed = new Date(last_viewed_cookie ? parseInt(last_viewed_cookie,10) : 0);

        var unread_count = 0;
        var html = '';
        for(var i=0; i<feed.items.length && i<8; i++) {
          var item = feed.items[i];

          // Hack to get a more useful snippet.
          // (Skip past "Blog post edited by Simon Baird")
          var snippet = item.description.split(/<p>/)[2].replace(/<[^>]+?>/g,'').substr(0,25) + '\u2026';

          var item_date = new Date(item.updated);
          var nice_date = $.datepicker.formatDate('dd-M-yy', item_date);
          var is_unread = last_viewed < item_date;

          html += '<li><a class="'+(is_unread ? 'unread' : '')+'" target="_blank" href="' + item.link + '">'+item.title+
            ' <span style="padding-left:4px!important;color:#aaa!important;">' + nice_date + ' - ' + snippet + '</span></a></li>';

          if (is_unread) {
            unread_count += 1;
          }
        }

        $('#rss_container').prepend(html);

        if (unread_count) {
          $('#unread_indicator').html('('+unread_count+')').show();
        }
      }
    });
  });

})(jQuery);

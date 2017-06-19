(function($) {

  $(function() {

    // Show/hide the file list for one dist
    $('.toggle-files').click(function(event) {
      event.preventDefault();
      $(this).closest('.dist-container').toggleClass('files-shown');
    });

    // Show/hide all the file lists for a build
    $('.expand-all').click(function(event) {
      event.preventDefault();
      $(this).closest('tr').find('.dist-container').addClass('files-shown');
    });
    $('.collapse-all').click(function(event) {
      event.preventDefault();
      $(this).closest('tr').find('.dist-container').removeClass('files-shown');
    });

    // Show RHN or CDN or both
    $('.show-rhn-only').click(function(event) {
      event.preventDefault();
      $('.content_list').removeClass('show-cdn-only').addClass('show-rhn-only');
    });
    $('.show-cdn-only').click(function(event) {
      event.preventDefault();
      $('.content_list').removeClass('show-rhn-only').addClass('show-cdn-only');
    });
    $('.show-all').click(function(event) {
      event.preventDefault();
      $('.content_list').removeClass('show-rhn-only').removeClass('show-cdn-only');
    });

  });

}(jQuery));

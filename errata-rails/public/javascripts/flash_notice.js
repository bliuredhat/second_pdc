/*
 * This function is called from application_helper.rb to show a flash
 * message loaded with an XHR request.
 * To start the animation we reset the animation name, which causes the
 * browser to re-play the animation.
 *
 */
;(function($){
  window.displayFlashNotice = function(noticeType, noticeMessage, noFade) {
    // Hide any that might be already showing
    $('.flash_container').find('.alert').hide();

    var alertType = {notice: 'success', alert: 'warning', error: 'error'};
    var noticeElem = $('#flash_' + noticeType);
    var closeButton = $('<a>', {
      text: '×',
      'class': 'close',
      'data-dismiss': 'alert',
    });

    /*
     * In case if a user already dismissed a flash message, create the
     * container again.
     *
     */
    if (!noticeElem.length) {
      noticeElem = $('<div>', {
        id: 'flash_' + noticeType,
        'class': 'alert alert-' + alertType[noticeType]
      });
      noticeElem.appendTo($('.flash_container'));
    }

    noticeElem
      .css('animation-name', 'none')
      .toggleClass('noFade', noFade)
      .html(noticeMessage)
      .append(closeButton);

    // Use setTimeout workaround for css animation weirdness.
    // The reason for using the timeout is not really clear.
    // Lower (< 5) millisecond values seem to cause it not to reset.
    // Something to do with DOM propagation or jQuery delay maybe..?
    setTimeout(function() {
      // Show notice then start the animation
      noticeElem.show().css('animation-name', 'fadeIn');
    }, 20);
  };

/*
 * On page load, we register one event handler, which keeps the flash
 * message in the view port if the user scrolls down.
 *
 */
$(function(){

  // (Might consider throttling this)
  $(window).scroll(function() {
    var offset = $(window).scrollTop() - ($('#eso-topbar').height() + $('#eso-topnav').height());
    $('.flash_container').toggleClass('nowFixed', offset > 0);
  });
});

})(jQuery);

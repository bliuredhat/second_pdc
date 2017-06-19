(function($) {

  $(function(){

    // So we don't show the loading indicator when user clicks back in Firefox
    // http://stackoverflow.com/questions/2638292/after-travelling-back-in-firefox-history-javascript-wont-run
    window.onunload = function(){};

    $('#new_choose').find('input').on('click', function() {
      $(this).closest('div').siblings('.selected').removeClass('selected')
      .end().toggleClass('selected',this.checked);
      $(this).closest('form').submit();
    });
  });

}(jQuery));

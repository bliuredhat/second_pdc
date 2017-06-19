(function ($) {

  /*
   * Set the wayback machine, we are resurrecting this function from
   * literally before the dawn of time*. See Bz 452540..
   * *ie, before git
  */
  function clearWaiveText(elem) {
    // Not sure I understand the requirements here, but this what the bug says..
    if ($(elem).val().match(/^This waiver is not ok because/)) {
      $(elem).val('');
    }
  }

  $(function() {
    $('#clear-waive-text').on('click', function(event) {
      event.preventDefault();
      $('#waive_text_textarea').val('');
    });

    $('#revert-waive-text').on('click', function(event) {
      event.preventDefault();
      $('#waive_text_textarea').val($(this).data('placeholder'));
    });

    $('#waive_text_textarea').on('focus', function() {
      clearWaiveText(this);
    });
  });

}(jQuery));
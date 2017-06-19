(function($) {

  $(function() {

    $(document).on('click', '#edit-brew-tags', function(event) {
      event.preventDefault();
      $('#edit_brew_tags_modal').modal({ dynamic: true });
    });

  });

}(jQuery));
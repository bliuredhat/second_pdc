(function($){

  $(function(){
    $('#release_list').on('change', '#release_id', function() {
      this.form.submit();
    });
  });

})(jQuery);
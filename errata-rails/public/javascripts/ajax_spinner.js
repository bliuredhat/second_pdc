(function($){

  $(document).on({
    ajaxStop: function() { $("body").removeClass("loading"); }
  });

})(jQuery);

(function($){

$(function(){

  $('.wrapped-unwrapped-container').find('.unwrap-toggle-btn').click(function(e){
    $(this).closest('.wrapped-unwrapped-container').toggleClass('show-unwrapped');
    e.preventDefault();
  });

});

})(jQuery);

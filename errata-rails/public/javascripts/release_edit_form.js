(function($) {

$(document).ready(function() {
  var brew_tag = $('.release_default_brew_tag')
  var pdcBox = $('#release_is_pdc');
  var showHideBrewTag = function(){
    brew_tag.toggle()
  }
  if (pdcBox.is(':checked')){
    brew_tag.hide();
  }
  pdcBox.change(showHideBrewTag)

});

}(jQuery));

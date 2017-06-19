(function($) {

  function highlightTypos(div_id, list) {
    var typos = list.split(",");
    var text = $('#'+div_id).html();
    $.each(typos, function(i, typo){
      text = text.replace(new RegExp('\\b'+ typo + '\\b','g'), '<span class="highlight-speling">' + typo + '</span>');
    });

    $('#'+div_id).html(text);
  }

  $(document).ready(function(){
    $('#spelling-errors').find('li').each(function(){
      highlightTypos($(this).data('key'), $(this).data('list'));
    });
  });

}(jQuery));

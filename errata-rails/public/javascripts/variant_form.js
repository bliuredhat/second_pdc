(function($) {

$(document).ready(function() {
  hide_tps_stream($("#variant_rhel_variant_id"));

  $('#variant_rhel_variant_id').on('change', function() {
    hide_tps_stream(this);
  });

  $('form').submit(function(event) {
    var element_name = 'variant[push_targets][]';
    var count = 0;
    $("input[name='" + element_name + "']").each(function() {
      if ($(this).prop('checked')) {
        count +=1;
      }
    });
    if (count <= 0) {
      var input =  $('<input>', {type: 'hidden', name: element_name, value: ''});
      $(this).append($(input));
    }
  });
});

// Hide the tps_stream field if rhel variant is blank
function hide_tps_stream(elem) {
  if (!$("#tps_stream_span").length) { return false; }

  var v_text = $(elem).find("option:selected").text();
  var v_name = $("#variant_name").val();

  if (v_text === '' || v_text === v_name) {
    $("#tps_stream_span").show();
  }
  else {
    $("#variant_tps_stream").val('');
    $("#tps_stream_span").hide();
  }
}

}(jQuery));
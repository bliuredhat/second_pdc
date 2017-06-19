(function($) {
  $(function() {
    var errata_id = $("#cpe_list_div").data("errata");
    $.ajax({
      "url": "/advisory/" + errata_id +"/cpe_list",
      "datatype": "script",
      "type": 'get',
      "data": {},
      "beforeSend": function(xhr) {
        $("#cpe_list_wait_spinner").show();
        return true;
      },
      "complete": function(xhr, text_status) {
        $("#cpe_list_wait_spinner").hide();
      },
      "success": function( data ) {
      },
      "error": function(jqXHR, textStatus, errorThrown){
        var response = jQuery.parseJSON(jqXHR.responseText);
        var error = (response && response.error) || "HTTP Error " + jqXHR.status;
        alert(error);
      },
    });
  });
}(jQuery));

(function($) {
// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults
$(document).ready(function() {
  init_ui_elements();
});

window.init_ui_elements = function() {
  $(".et-ui-autocomplete").each(function() {
    et_ui_autocomplete(this);
  });

  $(".et-ui-ajax-on-enter").keypress(send_ajax_request_on_enter);
  $(".et-ui-ajax-on-click").on('click', send_ajax_request_on_click);
};

function send_ajax_request_on_click(event) {
  event.preventDefault();
  send_ajax_request(this);
}

function send_ajax_request_on_enter(event) {
  // 13 is enter
  if (event.which === 13) {
    send_ajax_request(this);
    event.preventDefault();
  }
}

function send_ajax_request(element) {
  var _this = element;
  var $this = $(element);
  var url = $this.data('ajax-request-url');
  var label = $this.data('ajax-request-label') || 'name';
  var method = $this.data('ajax-request-method') || 'get';
  var params = $this.data('params') || {};
  params[label] = $this.val();

  $.ajax({
    "url": url,
    "datatype": "script",
    "type": method,
    "data": params,
    "beforeSend": function(xhr) {
      $("#wait_spinner").css("display", "inline");
      return true;
    },
    "complete": function(xhr, text_status) {
      $("#wait_spinner").css("display", "none");
      if ($this.is('input:text')) {
        document.getElementById(_this.id).focus();
      }
    },
    "success": function( data ) {
    },
    "error": function(jqXHR, textStatus, errorThrown){
      var error = jQuery.parseJSON(jqXHR.responseText).error || "HTTP Error " + jqXHR.status;
      alert(error);
    },
  });
  return true;
}

window.et_ui_autocomplete = function(element) {
  var url = $(element).data('autocomplete-url');
  var flabel = $(element).data('autocomplete-label') || 'name';
  var fvalue = $(element).data('autocomplete-value') || 'id';
  var fdesc  = $(element).data('autocomplete-desc')  || 'desc';
  var hidden = $(element).data('autocomplete-hidden');
  var params = $(element).data('autocomplete-params') || {};
  var submit_btn = $(element).data('autocomplete-submit-button') || "";
  submit_btn = (submit_btn && $('#' + submit_btn).length) ? $('#' + submit_btn) : ""

  var min_length = 2;

  $(element).autocomplete({
    source: function( request, response ) {
      params[flabel] = request.term;
      $.ajax({
        "url": url,
        "dataType": 'json',
        "type": "get",
        "data": params,
        "success": function( data ) {
          response( $.map( data, function( item ) {
          return { "label": item[flabel], "value": item[fvalue], "desc": item[fdesc] };
        }));},
        "error": function(jqXHR, textStatus, errorThrown){
          error = jQuery.parseJSON(jqXHR.responseText).error || "HTTP Error " + jqXHR.status;
          alert(error);
        },
      });
    },
    messages: { noResults: null, results: function() {} },
    minLength: min_length,
    create: function( event, ui ) {
      // textbox should be emptied when created so lock form
      if (submit_btn) disable_submit(submit_btn, true);
    },
    search: function( event, ui ) {
      // lock form when searching data
      if (submit_btn) disable_submit(submit_btn, true);
    },
    select: function( event, ui ) {
      $(element).val(ui.item.label);

      var hidden_field = $('#' + hidden);
      if ($(hidden_field).length) {
        $(hidden_field).val(ui.item.value);
      }

      // unlock form after select
      if (submit_btn && ui.item) disable_submit(submit_btn, false);

      return false;
     },
    }).data('autocomplete')._renderItem = function( ul, item ) {
      var re = new RegExp(this.term, "i");
      var desc_txt = "";

      if (item.desc) {
        desc_txt = " (<i>" + fdesc.substr(0, 1).toUpperCase() + fdesc.substr(1) + ":" + item.desc + "</i>)";
      }

      return $("<li></li>")
        .data("item.autocomplete", item)
        .append("<a>" + item.label.replace(re, "<b>" + this.term + "</b>") + desc_txt + "</a>")
        .appendTo(ul);
    };

  $(element).bind('keypress', function(e) {
    if (submit_btn && $(element).val().length < min_length) {
      // lock form if text length is less than the minimum allowed characters
      disable_submit(submit_btn, true);
    }
  });

  $(element).bind('paste', function(e) {
    setTimeout(function() {
        $(element).autocomplete('search', $(element).val());
      },
    0);
  });
  return $(element);
}

function disable_submit(submit_btn, disable) {
  var form_id = submit_btn.data('form-id');
  if (disable) {
    submit_btn.attr("disabled", true);
    $('#' + form_id).bind('submit',function(e){e.preventDefault();});
  }
  else {
    submit_btn.attr("disabled", false);
    $('#' + form_id).unbind('submit');
  }
}

window.et_xhr_error_to_string = function(xhr) {
  var errors,
    k,
    object,
    messages = [],
    out = 'HTTP ' + xhr.status + ' ' + xhr.statusText;

  try {
    object = $.parseJSON(xhr.responseText);
    errors = object.errors;
    if (errors) {
      for (k in errors) {
        if (!errors.hasOwnProperty(k)) {
          continue;
        }
        if (errors[k].length == 1) {
          // example: "name is already taken"
          messages.push(k + ' ' + errors[k][0]);
        } else {
          // example: "name: is too long (max: 5 characters), contains invalid characters
          messages.push(k + ': ' + errors[k].join(', '));
        }
      }
      out = messages.join('. ');
    } else {
      out = object.error;
    }
  } catch (err) {
  }

  return out;
};

window.toggle_div = function(div, elem) {
  $('#' + div).toggle();
  if (elem) {
    $('#' + elem).toggleClass('currently_hiding');
  }
};

}(jQuery));

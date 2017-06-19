$(function(){
  var get = function(items){
    return $($.grep( items, function( n, i ) {
      return $(n).length > 0;
    })[0])
  };
  var mapping_type = get(['input[name="multi_product_cdn_repo_map[mapping_type]"]',
                          'input[name="multi_product_channel_map[mapping_type]"]']);
  var origin = get(['input[name="multi_product_cdn_repo_map[origin]"]',
                    'input[name="multi_product_channel_map[origin]"]']);
  var destination = get(['input[name="multi_product_cdn_repo_map[destination]"]',
                         'input[name="multi_product_channel_map[destination]"]']);

  var short_name = $('span.short-name');
  var object_type = $('span.object-type');
  mapping_type.on('change', function(){
    var checked_type = get(['input[name="multi_product_cdn_repo_map[mapping_type]"]:checked',
                            'input[name="multi_product_channel_map[mapping_type]"]:checked']);
    var type = checked_type.val();
    var data_url = origin.data('autocomplete-url');
    // Since the model changes based on mapping type we need to switch some text
    // on UI and autocomplete url based on mapping type
    if (type === 'channel') {
      // switching autocomplete url for dist repo between
      // /cdn_repos/search_by_name_like and /channels/search_by_name_like
      data_url = data_url.replace(/cdn_repos/g, "channels");
      // switching short name and object type
      short_name.text(short_name.text().replace(/Cdn Repo/g, "Channel"))
      object_type.text(short_name.text().replace(/Cdn Repo/g, "Channel"))
    }
    else {
      data_url = data_url.replace(/channels/g, "cdn_repos");
      short_name.text(short_name.text().replace(/Channel/g, "Cdn Repo"))
      object_type.text(short_name.text().replace(/Channel/g, "Cdn Repo"))
    }
    origin.data('autocomplete-url', data_url);
    destination.data('autocomplete-url', data_url);
    init_ui_elements();
  });
});

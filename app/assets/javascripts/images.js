function loadImage(path, width, height, target) {
    $('<img src="'+ path +'">').load(function() {
      $(this).width(width).height(height).appendTo(target);
    });
}

document.addEventListener("turbolinks:load", function() {
  $('#upload_widget_opener').cloudinary_upload_widget(
  get_widget_options(),
  function(error, result) { 
     var results_array = result[0];
     var secure_url = results_array["secure_url"];
     loadImage(secure_url,90,60,"#uploaded_image");
  });
});

var get_widget_options = function(){
  var cropping = $("#cropping").data('cropping') || "server";
  var min_image_height = $("#min_image_height").data('min-image-height') || null;
  var max_image_height = $("#max_image_height").data('max-image-height') || null;
  var min_image_width = $("#min_image_width").data('min-image-width') || null;
  var max_image_width = $("#max_image_width").data('max-image-width') || null;
  var cropping_aspect_ratio = $("#cropping_aspect_ratio").data('cropping-aspect-ratio') || null;
  var cropping_default_selection_ratio = $("#cropping_default_selection_ratio").data('cropping-default-selection-ratio') || null;

  var options =  {
    cropping: cropping,
    min_image_width: min_image_width,
    max_image_width: max_image_width,
    min_image_height: min_image_height,
    max_image_height: max_image_height,
    cropping_aspect_ratio: cropping_aspect_ratio,
    cropping_default_selection_ratio: cropping_default_selection_ratio,
    cloud_name: "doohavoda",
    api_key:"393369625566631",
    upload_signature: generateSignature,
    public_id: $("#image_id").text()
  }


  console.log("options are:");
  console.log(options)

  return options;

}

var generateSignature = function(callback, params_to_sign){
  params_to_sign["_id"] = $("#image_id").text();
  params_to_sign["parent_id"] = $("#parent_id").text();
  params_to_sign["parent_class"] = $("#parent_class").text();
    $.ajax({
      url     : "/images",
      type    : "POST",
      dataType: "text",
      data    : { image: params_to_sign
            },
      complete: function() {console.log("complete")},
      success : function(signature, textStatus, xhr) {
       console.log("signature returned is:");
       console.log(signature);
       callback(signature); },
      error   : function(xhr, status, error) { console.log(xhr, status, error); }
    });
}

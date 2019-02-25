$(document).on('keypress','input:text',function(e){

	console.log("got keydown");

	var autocomplete_type = $(this).attr("data-autocomplete-type");

	var input_value = $(this).val();

	if(autocomplete_type == null){

	}
	else{
		$.get({
			url: "/search/type_selector",
			data: {
				type: autocomplete_type,
				query: 	input_value
			},
			dataType: "script"
		});
	}

});


function get_input_field_by_type(type){
		
}
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


$(document).on('click','.autocomplete_dropdown_element',function(e){
	$(this).parent().prev().val($(this).text());
	$(this).parent().prev().attr("data-hit-id",$(this).attr("data-hit-id"));
	$("#autocomplete_dropdown").remove();
});


$(document).on('click','body',function(e){
	
});
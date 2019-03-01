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
	// here if the parent, prev, has the data-multiple 
	// as true, 
	// then instead it has to create additional fields.
	// and add those as visible fields, somewhere below.
	// it will have to give them 
	// the next screen will have a list to choose from
	// the order has a series of statuses, they progress forwards
	// so first one is -> collect
	// 
	$("#autocomplete_dropdown").remove();
});


$(document).on('click','body',function(e){
	
});
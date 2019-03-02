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

/**
**/
var add_multiple_selection = function(parent_input_element,list_item_name,list_item_id){
	

	var multiple_element_name = parent_input_element.attr("data-multiple-element-name");
	
	var el = "<li class='collection-item'>" + list_item_name + "<input type='hidden' value='" + list_item_name + "' name='" + multiple_element_name + "' /></li>";
	
	var multiple_choices_element = "<ul id='" + parent_input_element.attr("id") + "_multiple" + "'></ul>";

	if($("#" + parent_input_element.attr("id") + "_multiple").length){

		//console.log("it exists");
		// so now on committing it should work.
	}
	else{
		
		$(multiple_choices_element).insertAfter($("#autocomplete_dropdown"));
	}

	$("#" + parent_input_element.attr("id") + "_multiple").append(el);
	

}

$(document).on('click','.autocomplete_dropdown_element',function(e){
	$(this).parent().prev().val($(this).text());
	$(this).parent().prev().attr("data-hit-id",$(this).attr("data-hit-id"));
	console.log("the data multiple value");
	console.log($(this).parent().prev().attr("data-multiple"));
	if($(this).parent().prev().attr("data-multiple") == "true"){
		console.log("it is true");
		add_multiple_selection($(this).parent().prev(),$(this).text(),$(this).attr("data-hit-id"));

	}
	// here if the parent, prev, has the data-multiple 
	// as true, 
	// then instead it has to create additional fields.
	// and add those as visible fields, somewhere below.
	// it will have to give them 
	// the next screen will have a list to choose from
	// the order has a series of statuses, they progress forwards
	// first one is collect ->
	// next one is assign tubes ->
	// next one is process ->
	// next one is verify ->
	// last one is completed ->
	$("#autocomplete_dropdown").remove();
});


$(document).on('click','body',function(e){
	
});
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

$(document).on('click','.delete_multiple_item',function(event){

	// will remove the parent list element.
	$(this).parent().remove();

});	


/**
**/
var add_multiple_selection = function(parent_input_element,list_item_name,list_item_id){
	

	var multiple_element_name = parent_input_element.attr("data-multiple-element-name");
	
	var el = "<li class='collection-item'>" + list_item_name + "<input type='hidden' value='" + list_item_name + "' name='" + multiple_element_name + "' /><i class='material-icons delete_multiple_item' style='cursor:pointer;'>close</i></li>";
	
	var multiple_choices_element = "<ul id='" + parent_input_element.attr("id") + "_multiple" + "'></ul>";

	if($("#" + parent_input_element.attr("id") + "_multiple").length){

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

	$("#autocomplete_dropdown").remove();
});


$(document).on('click','body',function(e){
	// unless it is the dropdown that is the target.
	if($(e.target).hasClass("autocomplete_dropdown_element")){

	}
	else{
		$("#autocomplete_dropdown").remove();
	}

});

// now show the existing report names.

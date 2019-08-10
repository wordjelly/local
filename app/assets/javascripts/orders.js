var get_item_group_id = function(){
	return $("#order_item_group_id").val();
}

var get_item_requirements = function(){
	console.log("getting item requirements");
	var item_requirements = [];
	
	$.each($(".item_requirement"),function(index,element){
		console.log("iterating element:");
		console.log(element);
		var requirement = {};
		requirement["type"] = $(element).find(".item_requirement_type").first().text();
		requirement["index"] = $(element).find(".item_requirement_index").first().text();
		requirement["barcode"] = $(element).find(".item_requirement_barcode").first().val();
		item_requirements.push(requirement);
	});

	console.log("item requirements are:");
	console.log(item_requirements);
	return item_requirements;
}

var get_patient_id = function(){
	return $("#order_patient_name").attr("data-hit-id");
}

var get_template_report_ids = function(){
	var template_report_ids = [];
	$.each($("[name='template_report_id']"),function(index,element){
		template_report_ids.push($(element).val());
	});
	return template_report_ids;
}

/***
on click choose report ->
***/

var add_report_to_order = function(report_id){
	$("form").first().append('<input name="order[template_report_ids][]" value="' + report_id + '" />');
}


$(document).on('click','.choose_report',function(event){
	add_report_to_order($(this).attr("data-id"));
	$("form").first().submit();
});


/**
ON CLICKING ADD REPORT MANUALLY
**/
$(document).on('click','.add_result_manually',function(event){
	var nested_element_id = $(this).attr("data-id");
	var nested_element = $("#" + nested_element_id);
	var result_raw = nested_element.find('[name="order[reports][][tests][][result_raw]"]');
	result_raw.parent().show();
});	

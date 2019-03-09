$(document).on('submit','.order_form',function(event){
	//console.log("got on submit");	
	// now what do we do.
	// on clicking the submit button.
	// we will send by js.
	// so we have total control.
	return false;
});


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

$(document).on('click','.submit_order',function(event){

	
	
	var data = {
		item_requirements: get_item_requirements(),
		patient_id: get_patient_id(),
		template_report_ids: get_template_report_ids()
	}

	console.log(data);
	if($(this).parent().attr("id").indexOf("edit") != -1){
		// if it is an edit form.
		console.log("the form is being edited");
		url = $(this).parent().attr("action") + ".js";
		$.ajax({
		    url: url,
		    type: 'PUT',
		    data: data
		});
	}
	else{
		$.post("/orders.js",data);
	}
});	
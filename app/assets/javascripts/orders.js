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
	$.each($("[name*=template_report_ids]"),function(index,element){
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
	var html_string = '';
	var pattern = new RegExp(/\-([^-]+)$/);

	_.each(get_template_report_ids(),function(el){
		html_string += '<div style="margin-left: 10px;">'
		var k = pattern.exec(el);
		html_string += k[1];
		html_string += '</div>,\n';
	});
	M.Toast.dismissAll();

	M.toast({html: "Reports in Order:" + html_string + '<button class="btn-flat toast_submit_form toast-action">Submit</button>', displayLength: 30000});
	//$("form").first().submit();
});

$(document).on('click','.toast_submit_form',function(event){
	$("form").first().submit();
})


/**
ON CLICKING ADD REPORT MANUALLY
**/
$(document).on('click','.add_result_manually',function(event){
	var nested_element_id = $(this).attr("data-id");
	var nested_element = $("#" + nested_element_id);
	var result_raw = nested_element.find('[name="order[reports][][tests][][result_raw]"]');
	result_raw.parent().show();
});	

$(document).on('click','.verify',function(event){
	var nested_element_id = $(this).attr("data-id");
	var nested_element = $("#" + nested_element_id);
	var verification_done = nested_element.find('[name="order[reports][][tests][][verification_done]"]');
	verification_done.val("1");
	$(".edit_order").first().submit();
});	

/***
on clicking top up it 
okay so this is done.
what about the balance button.
****/
$(document).on('click','#business_order_do_to_up_button',function(event){
	$("#business_order_do_top_up").val("1");
	$("form").first().submit();
});


$(document).on('click','#business_order_finalize_order_button',function(event){
	$("#business_order_finalize_order").val("1");
	$("form").first().submit();
});

$(document).on('click','#change_local_item_group_id',function(event){
	$("#business_order_local_item_group_id").toggle();
});

$(document).on('click','#force_pdf_generation_button',function(event){
	$("#business_order_force_pdf_generation").val("1");
	$("form").first().submit();
});

$(document).on('click','#add_reports_button',function(event){

	$("#add_reports_details").slideToggle();

});

// tubes
// payment receipts
// test editing -> adding values should be more simple.
$(document).on('click','#show_reports_list',function(event){
	var show_outsourced = $("#show_outsourced").prop("checked");
	var show_packages = $("#show_packages").prop("checked");
	$.get({
	  url: "/diagnostics/reports",
	  data: {show_outsourced: show_outsourced, show_packages: show_packages, reports_list: true},
	  success: function(data){
	  	if(_.isUndefined(template)){
			var template = _.template($('#reports_list_template').html());
		}
		$("#reports_list_holder").empty();
	  	_.each(data["reports"],function(report){
	  		console.log("Report is:");
	  		console.log(report);
	  		console.log(template(report));
	  		$("#reports_list_holder").append(template(report));
	  	});
	  }
	});
});

// and for the tubes ?
// we add the tubes.
// and we have to show the existing reports as well.
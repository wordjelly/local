$(document).on('submit','#new_report',function(event){
	console.log("got on submit");
	$(this).find("#report_test_id").val($(this).find("#report_test_name").attr("data-hit-id"));
	$(this).find("#report_item_requirement_id").val($(this).find("#report_item_requirement_name").attr("data-hit-id"));
});
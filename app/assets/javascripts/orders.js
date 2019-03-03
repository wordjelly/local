$(document).on('submit','.order_form',function(event){
	console.log("got on submit");
	$(this).find("#order_patient_id").val($(this).find("#order_patient_name").attr("data-hit-id"));
});
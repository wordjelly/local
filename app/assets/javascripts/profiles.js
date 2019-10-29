$(document).on('click','.accept_patient',function(event){
	$(this).parent().append("<input type='text' name='user[approved_patient_ids][] value='" + $(this).attr("data-user-id") + "' />");
	//$(this).appendBefore("<i class='large material-icons'>check</i>");
});

$(document).on('click','.reject_patient',function(event){
	$(this).parent().append("<input type='text' name='organization[rejected_patient_ids][] value='" + $(this).attr("data-user-id") + "' />");	
	//$(this).appendBefore("<i class='large material-icons'>check</i>");
});

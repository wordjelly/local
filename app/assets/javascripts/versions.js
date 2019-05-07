$(document).on("click",".reject_version",function(event){
	$("#verified_by_user_id" + "_" + $(this).attr("data-user-id")).prev(".verified_by_user_id").first().remove();
	M.toast({html: 'You rejected this version'});
});

$(document).on("click","verify_version",function(event){
	$(this).prepend("<input type='text' name='" + $(this).attr("data-attribute-name") + "' value='" + $(this).attr("data-user-id") + "' id='verified_by_user_id_" + $(this).attr("data-user-id") + "' />");
	M.toast({html: 'You accepted this version'});
});
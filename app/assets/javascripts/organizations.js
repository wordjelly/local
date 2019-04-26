$(document).on('click','.accept_user',function(event){
	$(this).parent().append("<input type='text' name='organization[user_ids][] value='" + $(this).attr("data-user-id") + "' />");
	$(this).appendBefore("<i class='large material-icons'>check</i>");
});

$(document).on('click','.reject_user',function(event){
	$(this).parent().append("<input type='text' name='organization[rejected_user_ids][] value='" + $(this).attr("data-user-id") + "' />");	
	$(this).appendBefore("<i class='large material-icons'>check</i>");
});

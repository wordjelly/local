function remove_verified_user_id(user_id){

}

function add_verified_user_id(user_id){

}

function remove_rejected_user_id(user_id){

}

function add_rejected_user_id(user_id){

}

$(document).on('click','.accept_user',function(event){
	$(this).parent().append("<input type='hidden' name='organization[user_ids][] value='" + $(this).attr("data-user-id") + "' />");
	$("<i class='large material-icons'>check</i>").insertBefore($(this));
});

$(document).on('click','.reject_user',function(event){
	$(this).parent().append("<input type='hidden' name='organization[rejected_user_ids][] value='" + $(this).attr("data-user-id") + "' />");	
	$("<i class='large material-icons'>check</i>").insertBefore($(this));
});

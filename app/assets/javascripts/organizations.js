function remove_verified_user_id(user_id){
	$("#" + user_id + "_verified").remove();
}

function add_verified_user_id(user_id,el){
	el.parent().append("<input type='hidden' name='organization[user_ids][]' id='" + el.attr("data-user-id") + "_verified' value='" + el.attr("data-user-id") + "' />");
	M.toast({html: 'User verified as belonging to this organization!'});
}

function remove_rejected_user_id(user_id){
	$("#" + user_id + "_rejected").remove();
}

function add_rejected_user_id(user_id,el){
	el.parent().append("<input type='hidden' name='organization[rejected_user_ids][]' id='" + el.attr("data-user-id") + "_rejected' value='" + el.attr("data-user-id") + "' />");
	M.toast({html: 'User rejected from belonging to this organization!'});
}

$(document).on('click','.accept_user',function(event){
	remove_rejected_user_id($(this).attr("data-user-id"));
	add_verified_user_id($(this).attr("data-user-id"),$(this));
});

$(document).on('click','.reject_user',function(event){
	remove_verified_user_id($(this).attr("data-user-id"));
	add_rejected_user_id($(this).attr("data-user-id"),$(this));
});
	
/***
on clicking toggle.
***/
$(document).on('click','.toggle',function(event){
	var target_element_id = $(this).attr("data-target-id");
	$("#" + target_element_id).slideToggle();
});


/**
before submitting the user form, we have to change its action.
change the form action to the mobile number.
if none is there
**/
$(document).on('click','#submit_sign_in_options',function(event){
	$(this).parent().attr("action","/users/" + $("#user_mobile_number").val());
	$(this).parent().submit();
});
_.templateSettings = {
    interpolate: /\{\{\=(.+?)\}\}/g,
    evaluate: /\{\{(.+?)\}\}/g
};

_.templateSettings.variable = 'search_result'; 

var template;

$(document).on('click','.add_nested_element',function(event){

	var template = _.template($(this).parent().prev().html());
	
	$(template({})).insertAfter($(this).parent());

});

/***
removes an existing nested element.
***/
$(document).on('click','.remove_nested_element',function(event){
	$(this).parent().prev().remove();
});

/***
shows the array of nested element.
***/
$(document).on('click','.nested_elements_dropdown',function(event){
	$(this).parent().next().slideToggle();
});
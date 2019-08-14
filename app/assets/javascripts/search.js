function navbar_search(query_string){
		var search_url = window.location.origin + "/app_search";
		$.get(
		{url : search_url,
		 data: { 
		    query: query_string
		 },
		 beforeSend: function(){
		 	//clear_search_results();
		 },
		 success : function( data ) {},
		 dataType : "script"
		});
}


$(document).on('keyup', '#search',function(event){
	navbar_search($(this).val());
});

/* Clear the search result if focus out from the title. */
$(document).on('click','body',function(event){
	if(event.target.id === 'search'){
		
	}
	else if(event.target.id === 'search_title'){
		
	}
	else{
		$(".search_result").remove();
	}
});

/* Highlight Autocomplete Matching Text */
var highlight = function() {
	
	var strings = $("#search").val().split(/\s+/);
	$(".search_result").mark(strings);

}

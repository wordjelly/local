$(document).on("submit",".new_item_requirement, .edit_item_requirement",function(event){
	//event.preventDefault();	
	$(".definition").each(function(index,el){
		var report_id_element = $(el).find(".report_id").first();
		var report_name_element = $(el).find(".report_name").first();
		if(_.isEmpty(report_id_element.val())){
			report_id_element.val(report_name_element.attr("data-hit-id"));
		}
	});
	// so let me sort out that shit
	// what do you want to display
	// given n report ids.
	// we search for all item_requirements, where that report_id
	// is present.
	// aggregate by item_type
	// then in that item type ->
	// aggregate by item_requirement_name
	// so we will get something like
	// okay so this is manageable.
	// let me first make something called tubes.
	// 
/***
	
	serum_tube => {
		golden_top => {
			"creatinine" => 10,
			"urea" => 10,
			"summate" => 332
		},
		red_top => {
			"whatever"
		},
		rst => {
			"whatever"
		}
	}

	so we now know we need three golden top tubes
	and we can assign stuff to them

	so we store nested shit.
	{
		item_requirement_id => "x",
		item_requirement_name => "x",
		report_ids => "",
		occupied_volume => x
	},
	{
		
	}

	so wnen a new report is added
	we aggregate similarly
	take each, get the last available one, and go forwards.
	so we can simplify things a lot like this.

***/
});
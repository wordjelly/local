// this is the add_item_definition function.
$(document).on('click','.add_existing_item',function(event){

	$(this).next().toggle();

});

$(document).on('click','.submit_existing_item_to_group',function(event){

	var item_id = $(this).prev().val();

	var params = {
		item: {
			local_item_group_id : $(this).attr("data-local-item-group-id"),
			item_type_id : $(this).attr("data-item-type-id"),
			expiry_date : $(this).attr("data-expiry-date"),
			transaction_id : $(this).attr("data-transaction-id"),
			supplier_item_group_id : $(this).attr("data-supplier-item-group-id")
		}
	}

	var params_string = $.param(params);

	//console.log("params string is:");
	//console.log(params_string);

	var getUrl = window.location;
	
	var url = getUrl .protocol + "//" + getUrl.host + "/" + getUrl.pathname.split('/')[1] + "/items/"  +  item_id + "/edit?" + params_string;

	window.location.href = url;

	//console.log("base url is:" + baseUrl);
});

$(document).on('click','.add_item_definition',function(event){
	// together with this it should have the remove icon.
	// and somehow seperate and indent
	var item_definition_element = `
		<div class="card item_definition">
    		<div class="card-content">
      			<div class="card-title">
					<input type="text" data-use-id="yes" name="item_group[item_definitions][][item_type_id]" data-autocomplete-type="inventory-item-types" />
					<label for="item_group[item_definitions][][item_type_id]">Item Type Id</label>
					<input type="text" name="item_group[item_definitions][][quantity]" />
					<label for="item_group[item_definitions][][quantity]">Quantity</label>
					<input type="text" name="item_group[item_definitions][][expiry_date]" class="datepicker" />
					<label for="item_group[item_definitions][][expiry_date]">Expiry Date</label>
					<span><i class="material-icons remove_item_definition">clear</i>Remove Item Definition</span>
				</div>
			</div>
		</div>
		`;

	$(item_definition_element).insertBefore($(this).parent().parent());
	$('.datepicker').datepicker({
        format: "yyyy-mm-dd"
    });
});

// since the remove item definition button is nested 
// inside the item definition 
$(document).on('click','.remove_item_definition',function(event){
	$(this).parent().parent().parent().remove();
});

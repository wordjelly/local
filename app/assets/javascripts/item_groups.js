// this is the add_item_definition function.
$(document).on('click','.add_item_definition',function(event){
	// together with this it should have the remove icon.
	// and somehow seperate and indent
	var item_definition_element = `
		<div class="card item_definition">
    		<div class="card-content">
      			<div class="card-title">
					<input type="text" name="item_group[item_definitions][][item_type_id]" data-autocomplete-type="item-types" />
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
});

// since the remove item definition button is nested 
// inside the item definition 
$(document).on('click','.remove_item_definition',function(event){
	$(this).parent().parent().parent().remove();
});

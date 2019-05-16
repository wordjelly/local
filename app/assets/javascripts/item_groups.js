$(document).on('click','.add_item_id',function(event){
	var item_id_input_element = '<div class="item_id"><input type="text" name="item_group[item_ids][]" data-autocomplete-type="inventory-items" /><i class="material-icons remove_item_id">remove</i></div>';
	$(item_id_input_element).insertBefore($(this));
});

$(document).on('click','.remove_item_id',function(event){
	$(this).parent().remove();
});
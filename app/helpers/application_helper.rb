module ApplicationHelper
	## @param[Array] items: the array of items that have to be displayed.
	## @param[String] item_path : for eg: report[status_ids] : if we are displaying status ids,  
	def add_multiple_items(items,item_path)
		html = "<ul>"
		items.each do |item|
			html += "<li class='collection-item'>#{item.name}
			<input type='hidden' name='#{item_path}[]' value='#{item.id.to_s}' />
			<i class='material-icons delete_multiple_item' style='cursor:pointer;'>close</i>
			</li>"
		end	
		html += "</ul>"
	end	

	## @param[Array] applicable_status
	def is_delayed?(applicable_status)
		if applicable_status.size == 1
			""
		else
			if Time.now.to_i > applicable_status[0][:expected_time]
				if applicable_status[0][:performed_at].blank?
					"red-text"
				else
					""
				end
			else
				""
			end
		end
	end	

end

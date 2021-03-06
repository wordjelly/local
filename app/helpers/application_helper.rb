module ApplicationHelper
	## @param[Array] items: the array of items that have to be displayed.
	## @param[String] item_path : for eg: report[status_ids] : if we are displaying status ids
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

	## @return[Geo::Location] the first location of the organization 
	def get_current_user_organization_location
		if current_user.has_organization?
			if current_user.organization.locations.blank?
				nil
			else
				current_user.organization.locations[0]
			end
		else
			nil
		end
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

	def get_navigation_partial_name(current_user)
		if current_user.blank?
			"no_user"
		else
			if current_user.owns_or_belongs_to_organization?
				current_user.organization.role
			else
				"user_no_role"
			end
		end
	end


	def report_message(report)
		unless report.worth_processing.blank?
			## if its not blank -> 
			""
		else
			"Add required tubes/consumables & answer all history questions to proceed"
		end
	end

end

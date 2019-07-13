module Concerns::FormConcern

	extend ActiveSupport::Concern

	included do 

		def fields_not_show_in_form
			["created_at","updated_at","public","currently_held_by_organization","created_by_user_id","owner_ids"]		
		end
		## @param[String] root: the root name for any input element.
		## for eg if the name of the object is Inventory::Item, then this will be item. Whatever you would have passed into form_for as:"" the as option.
		## as you traverse down nested trees, you have to go on appending the relevant stub to it.
		## @param[String] readonly: if you want to show this object, and don't want to edit it, set readonly to "yes"
		## then all the input parameters will be :readonly, and no add/remove buttons will be there for nested objects. 
		def build_form(root,readonly="no",form_html="")
			
			## its possible if the attribute is encountered twice.
			self.class.attribute_set.each do |virtus_attribute|
				
				next if self.fields_not_show_in_form.include? virtus_attribute.name.to_s

				if virtus_attribute.primitive.to_s == "Array"
					
					## this should be collapsible.
					## this should be openable also.
					## it should have the titles
					## and each element should have a delete option at the end of its form.
					## that can also be added via the array.
					## on clicking the nested section
					## it will show the next element.
					## basically it will toggle it.
					## 
					form_html = form_html + "<div class='h4'><i class='material-icons nested_elements_dropdown'>expand_more</i>" + virtus_attribute.name.to_s + "(" + self.send(virtus_attribute.name).size.to_s + ")</div>"
					
					form_html = form_html + "<div class='row nested_elements' style='display:none;'>"
						## this is added to have a default dummy value for the array in case all the elements are removed.
						form_html = form_html + "<input name='" + root + "[" + virtus_attribute.name.to_s + "][]" + "' type='hidden' />"
						self.send(virtus_attribute.name).each do |arr|
							form_html = form_html + "<div class='row nested_element'>"
							form_html = form_html + arr.build_form(root + "[" + virtus_attribute.name.to_s + "][]",readonly,"")
							form_html = form_html + "</div>"
							## now here we add something to remove this.
							## merge is not overridding empty elements
							## this is a problem.
							form_html = form_html + "<span><i class='material-icons remove_nested_element'>remove_circle_outline</i></span>"
						end

						if virtus_attribute.respond_to? "member_type"
						#puts "came to member type"
						#puts "the attribute name is:"
						#puts virtus_attribute.name.to_s
							class_name = virtus_attribute.member_type.primitive.to_s 
							#puts "the basic type is:"
							#puts class_name.to_s
							unless class_name == "BasicObject"
								dummy_entry = class_name.constantize.new
								additional_element = "<div class='row' style='padding-left: 1rem;'>" + dummy_entry.build_form(root + "[" + virtus_attribute.name.to_s + "][]",readonly,"") + "</div>"
								form_html = form_html + '<script type="text/template" class="template">' + additional_element + '</script>'
								form_html += "<span><i class='material-icons add_nested_element'>add_circle_outline</i>Add</span>"
							end
						else
							
						end

					form_html = form_html + "</div>"

					
				elsif virtus_attribute.primitive.to_s == "Date"
					
					input_name = root + "[" + virtus_attribute.name.to_s + "]"
					
					form_html = form_html + '''
						<input class="datepicker" type="text" name="''' + input_name + '''" value="''' + self.send(virtus_attribute.name.to_s).to_s + '''"></input>
					'''

					form_html = form_html + '''
						<label for="''' + input_name + '''">''' + virtus_attribute.name.to_s + '''</label>
					'''
					## if it is readonly, then set it like that.

				elsif virtus_attribute.primitive.to_s == "Integer"


					input_name = root + "[" + virtus_attribute.name.to_s + "]"
					
					form_html = form_html + '''
						<input type="number" name="''' + input_name + '''" value="''' + self.send(virtus_attribute.name.to_s).to_s + '''"></input>
					'''

					form_html = form_html + '''
						<label for="''' + input_name + '''">''' + virtus_attribute.name.to_s + '''</label>
					'''

				elsif virtus_attribute.primitive.to_s == "Float"
					
					input_name = root + "[" + virtus_attribute.name.to_s + "]"
					
					form_html = form_html + '''
						<input type="number" name="''' + input_name + '''" value="''' + self.send(virtus_attribute.name.to_s).to_s + '''"></input>
					'''

					form_html = form_html + '''
						<label for="''' + input_name + '''">''' + virtus_attribute.name.to_s + '''</label>
					'''

				else

					input_name = root + "[" + virtus_attribute.name.to_s + "]"
					
					form_html = form_html + '''
						<input type="text" name="''' + input_name + '''" value="''' + self.send(virtus_attribute.name.to_s).to_s + '''"></input>
					'''

					form_html = form_html + '''
						<label for="''' + input_name + '''">''' + virtus_attribute.name.to_s + '''</label>
					'''

				end
			end

			form_html

		end

	end

end
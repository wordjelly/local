module Concerns::FormConcern

	extend ActiveSupport::Concern

	included do 


		

		def fields_not_show_in_form
			["created_at","updated_at","public","currently_held_by_organization","created_by_user_id","owner_ids"]		
		end

		## if the attribute name is mentioned in this hash.
		## will apply whatever is at the value of the key.
		def customizations(root)
			{}
		end


		attr_accessor :object_array_attributes

		attr_accessor :plain_array_attributes

		attr_accessor :non_array_attributes

		## first classify the attributes for the purpose of rendering.
		## once this is done, make tabs out of the others
		## so we have something called render attributes
		## so we go and render the summary, and below it call render form.
		## just keep it hidden.
		## just show the summary, and keep the rest of it hidden.
		## so take the array attributes.
		## make tabs
		## for each attribute
		## render summary 
		## render a row
		## then in the same tr
		## call build form on the nested attribute
		## 
		def classify_attributes
			
			self.object_array_attributes = []
			
			self.plain_array_attributes = []
			
			self.non_array_attributes = []

			self.class.attribute_set.select{|c| 
				if c.primitive.to_s == "Array"
					if c.respond_to? "member_type"
						if c.member_type.primitive.to_s != "BasicObject"
							self.plain_array_attributes << c.name
						else
							self.object_array_attributes << c.name
						end
					else
						c.non_array_attributes << c.name
					end
				else
					c.non_array_attributes << c.name
				end
			}
		end

		def add_date_element

		end

		def add_number_element

		end

		def add_text_element

		end

		def new_build_form(root,readonly="no",form_html="",scripts={})
			classify_attributes
			## card initialize.
			## add the title.
			card = '''
				<div class="card">
					<div class="card-content">
						<div class="card-title">
						</div>
			'''

			self.non_array_attributes.each do |flat|
				if flat.is_a_date?
				elsif flat.is_a_number?
				else
				end
			end
			
			self.plain_array_attributes.each do |plain_array|

			end

			## open here 
			## and then proceed.

			self.object_array_attributes.each do |object_array|

				## for each array attribute
				## render a summary row
				## then render the entire form
				## in a hidden div.

			end


		end

		## @param[String] root: the root name for any input element.
		## for eg if the name of the object is Inventory::Item, then this will be item. Whatever you would have passed into form_for as:"" the as option.
		## as you traverse down nested trees, you have to go on appending the relevant stub to it.
		## @param[String] readonly: if you want to show this object, and don't want to edit it, set readonly to "yes"
		## then all the input parameters will be :readonly, and no add/remove buttons will be there for nested objects. 
		def build_form(root,readonly="no",form_html="",scripts={})
			
			## its possible if the attribute is encountered twice.
			self.class.attribute_set.each do |virtus_attribute|
				
				next if self.fields_not_show_in_form.include? virtus_attribute.name.to_s

				unless customizations(root)[virtus_attribute.name.to_s].blank?
					
					form_html = form_html + customizations(root)[virtus_attribute.name.to_s]

				else

					if virtus_attribute.primitive.to_s == "Array"
			
							#puts "Array is: #{virtus_attribute.name}, class is: #{self.class.name}"

							s = "<div class='h4'><i class='material-icons nested_elements_dropdown'>expand_more</i>" + virtus_attribute.name.to_s + "(" + self.send(virtus_attribute.name).size.to_s + ")</div>"
						
							s = s + "<div class='row nested_elements' style='display:none;'>"
							## this is added to have a default dummy value for the array in case all the elements are removed.
							## it got added nested here.
							## actually.
							s = s + "<input name='" + root + "[" + virtus_attribute.name.to_s + "][]" + "' type='hidden' />"


							if virtus_attribute.respond_to? "member_type"

								class_name = virtus_attribute.member_type.primitive.to_s

								script_id = BSON::ObjectId.new.to_s 

								unless self.send(virtus_attribute.name).blank?
									if class_name.to_s == "BasicObject"
										
									else
										self.send(virtus_attribute.name).each do |arr_el|
											s += '<div style="padding-left: 1rem;">' +  arr_el.build_form(root + "[" + virtus_attribute.name.to_s + "][]",readonly,"",scripts) + '</div>'
										end
									end
								end

								if class_name.to_s == "BasicObject"
						
									scripts[script_id] = '<script  id="' + script_id +'" type="text/template" class="template">' +  "<input type='text' name='" + root + "[" + virtus_attribute.name.to_s + "][]" + "' /></script>"
									element = "<span><i data-id='#{script_id}' class='material-icons add_nested_element'>add_circle_outline</i>Add</span>"
									
								else
									dummy_entry = class_name.constantize.new
									scripts[script_id] = '<script id="' + script_id +'" type="text/template" class="template"><div style="padding-left: 1rem;">' + dummy_entry.build_form(root + "[" + virtus_attribute.name.to_s + "][]",readonly,"",scripts) + "</div></script>"
									

									element = "<span><i class='material-icons add_nested_element' data-id='#{script_id}'>add_circle_outline</i>Add</span>"
									
								end
								s = s + element
								
							end


							form_html = form_html + s + "</div>"
				
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

			end

			form_html

		end

	end

end
module Concerns::FormConcern

	extend ActiveSupport::Concern
	include ActionView::Helpers::UrlHelper
	include ActionView::Helpers::FormHelper
	include ActionView::Helpers::FormOptionsHelper

	included do 

		## this should be contextual.

		def fields_not_to_render
			#["created_at","updated_at","public","currently_held_by_organization","created_by_user_id","owner_ids","procedure_version","search_options"]		
			[]
		end

		## will check dthe keys for the root.
		## if any of the keys are found in the root, then it will return that otherwise defaults to the star.
		## so it will take the root and see if any of the keys have it.
		## then will return that.
		## otherwise will return these defaults.
		## set for all.
		def fields_not_to_show_in_form_hash(root="*")
			{
				"*" => ["created_at","updated_at","public","currently_held_by_organization","created_by_user_id","owner_ids","procedure_version","outsourced_report_statuses","merged_statuses","search_options"]
			}
		end

		

		## if the attribute name is mentioned in this hash.
		## will apply whatever is at the value of the key.
		def customizations(root)
			{}
		end

		## used in the /shared/display_nested.html.erb partial.
		## if the attribute is found in this, then it will be rendered 
		## as defined here.
		## that is not working because add_new_payment is not working.
		def display_customizations(root=nil)
			{}
		end

		attr_accessor :object_array_attributes

		attr_accessor :plain_array_attributes

		attr_accessor :non_array_attributes

		## a unique id is made for the object, 
		## and used to set ids on divs and tabs
		## this is used in summary row, and everywhere else.
		## while making the form.
		attr_accessor :unique_id_for_form_divs

		def set_unique_id_for_form
			self.unique_id_for_form_divs = (self.id.to_s.parameterize.underscore + BSON::ObjectId.new.to_s) if self.unique_id_for_form_divs.blank?
		end

		## returns the fileds which are to be hidden in the form, depending on the root context.
		## @param[String] root : root is a string.
		## @return[Array] list of fields, which are strings.
		def fields_to_hide(root)
			hash_of_fields = fields_not_to_show_in_form_hash
			
			fields_not_to_show_in_form = []

			hash_of_fields.keys.each do |k|
				if root =~ /#{Regexp.escape(k)}/
					fields_not_to_show_in_form = hash_of_fields[k]
					break
				end
			end

			fields_not_to_show_in_form = hash_of_fields["*"] if fields_not_to_show_in_form.blank?

			fields_not_to_show_in_form
		end


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
		def classify_attributes(root)
			
			self.object_array_attributes = []
			
			self.plain_array_attributes = []
			
			self.non_array_attributes = []

			self.class.attribute_set.select{|c| 
				## this has to be contextual on the root.
				next if fields_not_to_render.include? c.name.to_s
				if c.primitive.to_s == "Array"
					if c.respond_to? "member_type"
						if c.member_type.primitive.to_s == "BasicObject"
							self.plain_array_attributes << c
						else
							self.object_array_attributes << c
						end
					else
						self.non_array_attributes << c
					end
				else
					self.non_array_attributes << c
				end
			} 
			
		end

		## there are 2-3 possibilities.
		## 1 -> manual entry (somehow has to be verified by two people)
		## so if i for a test, enter the value manually, i can have a simple re-enter the value, in case of manual entry, another doctor has to verify that report ? or a technician has to verify that report, on clicking verify, it should satisfy a challenge ?
		## of some kind.
		## that all can be done
		## then the generation of the impression -> can be automated from the grades in the test, or can be manually entered.
		## in certain cases it is mandatory. 
		## 2 -> lis entry (has to be verified)
		## 3 -> lis re-run (request rerun has to be on)


		## @param[String] root : the form root.
		## @param[Virtus::Attribute] : the virtus attribute
		## @param[Boolean] hidden : if true, then the element should be hidden, wrapped in a div with display none.
		## @return[String] html snippet, for date selector.
		def add_date_element(root,virtus_attribute,hidden)
			
			input_name = root + "[" + virtus_attribute.name.to_s + "]"

			element =  	'''
				<input class="datepicker" type="text" name="''' + input_name + '''" value="''' + self.send(virtus_attribute.name.to_s).to_s + '''"></input>
			'''

			element += '''
				<label for="''' + input_name + '''">''' + virtus_attribute.name.to_s + '''</label>
			'''

			if hidden == true
				'<div style="display:none;">' + element + '</div>'
			else
				element
			end

		end


		def add_float_element(root,virtus_attribute,hidden)

			input_name = root + "[" + virtus_attribute.name.to_s + "]"
						
			element = '''
				<input type="number" name="''' + input_name + '''" value="''' + self.send(virtus_attribute.name.to_s).to_s + '''"></input>
			'''

			element += '''
				<label for="''' + input_name + '''">''' + virtus_attribute.name.to_s + '''</label>
			'''

			element

			if hidden == true
				'<div style="display:none;">' + element + '</div>'
			else
				element
			end

		end

		## adds the id element.
		## it is always hidden.
		## adds it as a hidden element to the non_array_attributes.
		def add_id_element(root)

			input_name = root + "[id]"
						
			element = '''
				<input type="text" name="''' + input_name + '''" value="''' + self.send("id").to_s + '''"></input>
			'''

			element += '''
				<label for="''' + input_name + '''">id</label>
			'''

			
			'<div style="display:none;">' + element + '</div>'
			
		end

		def add_text_element(root,virtus_attribute,hidden)

			input_name = root + "[" + virtus_attribute.name.to_s + "]"
						
			element = '''
				<input type="text" name="''' + input_name + '''" value="''' + self.send(virtus_attribute.name.to_s).to_s + '''"></input>
			'''

			element += '''
				<label for="''' + input_name + '''">''' + virtus_attribute.name.to_s + '''</label>
			'''

			element

			if hidden == true
				'<div style="display:none;">' + element + '</div>'
			else
				element
			end

		end

		## this gets overriden in the different things.
		def summary_row(args={})

		end

		## should return the table, and th part.
		def summary_table_headers(args={})

		end

		def summary_table_open
			'''
				<table class="striped">
			'''
		end

		def summary_table_body_open
			'''
				<tbody>
			'''
		end

		def summary_table_body_close
			'''
				</tbody>
			'''
		end

		def summary_table_close
			'''
				</table>
			'''
		end

		def add_new_plain_array_element(root,collection_name,scripts,readonly)

			script_id = BSON::ObjectId.new.to_s

			script_open = '<script id="' + script_id + '" type="text/template" class="template"><div style="padding-left: 1rem;">'
			
			scripts[script_id] = script_open

			scripts[script_id] +=  '<input type="text" name="' + root + '[' + collection_name + '][]" /> <label for="' + root + '[' + collection_name + '][]">' + collection_name.singularize + '</label><i class="material-icons remove_element">close</i></div></script>'
		
			element = "<a class='waves-effect waves-light btn-small add_nested_element' data-id='#{script_id}'><i class='material-icons left' >cloud</i>Add #{collection_name.singularize}</a>"

			element

		end

		## @param[String] root
		## @param[String] collection_name : eg "reports"
		## @param[Hash] scripts : the scripts hash
		## @param[String] readonly 
		## this will be a category.
		## so we do this in categories.
		def add_new_object(root,collection_name,scripts,readonly)
			
			script_id = BSON::ObjectId.new.to_s

			script_open = '<script id="' + script_id + '" type="text/template" class="template"><div style="padding-left: 1rem;">'
			
			scripts[script_id] = script_open

			scripts[script_id] +=  new_build_form(root + "[" + collection_name + "][]",readonly,"",scripts) + '</div></script>'
		
			element = "<a class='waves-effect waves-light btn-small add_nested_element' data-id='#{script_id}'><i class='material-icons left' >cloud</i>Add #{collection_name.singularize}</a>"

			element

		end

		def add_tab_title(attribute_name,bson_id)
			# here the title and content.
			'<li class="tab col s3 m3 l3"><a href="#' + attribute_name.to_s + bson_id + '">' + attribute_name.to_s + '</a></li>'
		end

		def open_tab_content(attr_name,bson_id)
			# here too the title and content
			'<div id="' + attr_name.to_s + bson_id + '" class="col s12 m12 l12">'
		end

		def close_tab_content(attr_name)
			'</div>'
		end

		def add_hidden_nested_object(editable_tab_content,tab_titles,tab_content,attr,root,scripts,readonly)
			unless self.send(attr.name).blank?
				self.send(attr.name).each do |obj|
					obj.set_unique_id_for_form
					#puts "doing object class: #{obj.class.name.to_s}"
					#tab_content += obj.summary_row({"root" => root})
					editable_tab_content += '<div class="nested_object_details" id="' + obj.unique_id_for_form_divs + '" style="display:none;">'
					editable_tab_content += obj.new_build_form(root + "[" + attr.name.to_s + "][]",readonly="no","",scripts)
					editable_tab_content += '</div>'
				end
			end
			return editable_tab_content
		end

		def add_visible_nested_object(editable_tab_content,tab_titles,tab_content,attr,root,scripts,readonly)

			bson_id = BSON::ObjectId.new.to_s
				
			## again here, we can have it as hidden ?
			## these have to be hidden.
			tab_titles += add_tab_title(attr.name,bson_id)

			#puts "after adding tab titles they becom:"
			#puts tab_titles.to_s

			empty_obj = attr.member_type.primitive.to_s.constantize.new
			
			tab_content += open_tab_content(attr.name,bson_id)

			unless self.send(attr.name).blank?
				tab_content += self.send(attr.name)[0].summary_table_open
				#puts "the attr name is: #{self.send(attr.name)}"
				tab_content += self.send(attr.name)[0].summary_table_headers({"root" => root})
				tab_content += self.send(attr.name)[0].summary_table_body_open

				self.send(attr.name).each do |obj|
					obj.set_unique_id_for_form
					#puts "doing object class: #{obj.class.name.to_s}"
					tab_content += obj.summary_row({"root" => root})
					editable_tab_content += '<div class="nested_object_details" id="' + obj.unique_id_for_form_divs + '" style="display:none;">'
					editable_tab_content += obj.new_build_form(root + "[" + attr.name.to_s + "][]",readonly="no","",scripts)
					editable_tab_content += '</div>'
				end
				tab_content += self.send(attr.name)[0].summary_table_body_close
				tab_content += self.send(attr.name)[0].summary_table_close
			end
			## that is the add new part.
			## so this can be a category, report or 
			tab_content += empty_obj.add_new_object(root,attr.name.to_s,scripts,readonly)
			#puts "--------------------------------------"
			#puts "editable tab content is:"
			#puts editable_tab_content
			#puts "--------------------------------------"
			tab_content += editable_tab_content
			tab_content += close_tab_content(attr.name)

			
			#puts "the tab content returned is:"
			#puts tab_content.to_s

			return {
				:titles => tab_titles,
				:content => tab_content,
				:editable => editable_tab_content
			}

		end

		## @param[Array => Virtus::Attribute] object_array_attributes : 
		## @param[Array => String] hidden_fields_list : the list of strings which are the hidden fields.
		## @return[Boolean] basically checks if there are any object array attributes that are not hidden.
		## @called_from : #new_build_form 
		def non_hidden_object_arrays_exist?(object_array_attributes,hidden_fields_list)
			(object_array_attributes.map{|c| c.name.to_s} & hidden_fields_list).size < object_array_attributes.size
		end

		def new_build_form(root,readonly="no",form_html="",scripts={})
			
			hidden_fields_list = fields_to_hide(root)

			set_unique_id_for_form
			
			classify_attributes(root)
			
			non_array_attributes_card = '''
				<div class="card">
					<div class="card-content">
						<div class="card-title">
			''' 

			if self.respond_to? :name
				if self.name.blank?
					non_array_attributes_card += "New Record"
				else
					non_array_attributes_card += self.name
				end
			else
				non_array_attributes_card += "New Record"
			end

			#<a href="#categories5d45289cacbcd65941ef89ae" class="">categories</a>

			non_array_attributes_card += '''
						</div>
			'''

			## so i could make it tabbed right away.

			self.non_array_attributes.each do |nattr|
				unless customizations(root)[nattr.name.to_s].blank?
					
					non_array_attributes_card += customizations(root)[nattr.name.to_s]

				else

					if nattr.primitive.to_s == "Date"
						non_array_attributes_card += add_date_element(root,nattr,(hidden_fields_list.include? nattr.name.to_s))
					elsif nattr.primitive.to_s == "Integer"
						## add number element
						non_array_attributes_card += add_float_element(root,nattr,(hidden_fields_list.include? nattr.name.to_s))
					elsif nattr.primitive.to_s == "Float"
						## add float element.
						non_array_attributes_card += add_float_element(root,nattr,(hidden_fields_list.include? nattr.name.to_s))
					else
						non_array_attributes_card += add_text_element(root,nattr,(hidden_fields_list.include? nattr.name.to_s))
					end

				end
			end

			## add id. to this.
			non_array_attributes_card += add_id_element(root)


			non_array_attributes_card += "</div></div>"


			plain_array_attributes_block = ''

			## see why colloquials are not working.

			self.plain_array_attributes.each do |nattr|

				card_style=''

				hide_field = hidden_fields_list.include? nattr.name.to_s

				if hide_field == true
					card_style = "display:none;"
				end

				plain_array_attributes_card = ''
					
				## so this card has to be hidden.

				plain_array_attributes_card += '
					<div class="card" style="' + card_style + '">
						<div class="card-content">
							<div class="card-title">
				'

				plain_array_attributes_card += nattr.name.to_s
				
				plain_array_attributes_card += '</div>'

				self.send(nattr.name).each do |arr_el|
					#puts "doing arr el: #{arr_el}"
					#puts "nattrn name: #{nattr.name}"
					#puts "root is: #{root}"
					plain_array_attributes_card += '<input type="text" name="' + root + '[' + nattr.name.to_s + '][]' + '" value="' + arr_el.to_s + '" />'
				end 
				
				plain_array_attributes_card += add_new_plain_array_element(root,nattr.name.to_s,scripts,readonly)

				plain_array_attributes_card += "</div></div>"
					
				plain_array_attributes_block += plain_array_attributes_card

			end

	
			object_array_attributes_cards = ''

			tab_titles = ''

			## only if these are not to be hidden.

			tab_titles = '<div class="row"><div class="col s12 m12 l12">
      		<ul class="tabs tabs-fixed-width">' if (non_hidden_object_arrays_exist?(object_array_attributes,hidden_fields_list))

			tab_content = ''



			self.object_array_attributes.each do |attr|

				## if this attribute has to be hidden, then only the editable tab content has to be populated.
				hide_field = hidden_fields_list.include? attr.name.to_s
				editable_tab_content = ''

				#puts "field name is: #{attr.name.to_s} and hide field is: #{hide_field.to_s} "

				if hide_field == true
					editable_tab_content = add_hidden_nested_object(editable_tab_content,tab_titles,tab_content,attr,root,scripts,readonly)
				else
					#puts "going to add visible object"
					results = add_visible_nested_object(editable_tab_content,tab_titles,tab_content,attr,root,scripts,readonly)
					editable_tab_content = results[:editable]
					tab_titles = results[:titles]
					tab_content = results[:content]
				end

				#puts "tab title becomes:"
				#puts tab_titles

				#puts "tab content becomes:"
				#puts tab_content

				#puts "editable tab content is:"
				#puts editable_tab_content

				#puts "-------------------------- DONE FOR FIELD: #{attr.name.to_s} ----------------------- "
				
			end

			k = non_array_attributes_card + plain_array_attributes_block + tab_titles  
			
			k += '</ul></div></div>' if (non_hidden_object_arrays_exist?(object_array_attributes,hidden_fields_list))
			
			k += tab_content
			
			k

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
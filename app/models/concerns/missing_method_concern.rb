## THIS CONCERN HAS TO BE THE LAST INCLUDED CONCERN
## IN THE CONCERNS OF ANY MODEL.
module Concerns::MissingMethodConcern

	extend ActiveSupport::Concern

	included do 
		include ActiveModel::Validations
  		include ActiveModel::Validations::Callbacks

  		attr_accessor :changed_attributes
		# before validate , we call a methdo on order
		# it takes each report, and sets the parent report id
		# on the children, as well as the organization id, where
		# the report originated from.
		# if it doesn't exist this is done,
		# because otherwise, we will have to send this in from the 
		# client side
		# if you want to add an item.
		# if you want to add a category
		# we pass in the currently held by organization, and the parent id
		# like of the report.
		# we can have something like assign top level organization, user 
		# so report -> goes to its 
		#before_validation do |document|
		#	document.assign_parent_details
		#end

		validate :validate_nested

		

		before_save do |document|
			puts "CAME TO BEFORE SAVE ------------------- in missing method concern #{document.class.name}"
			puts "ERRORS AT THIS STAGE: #{document.errors.full_messages}"
			document.nullify_nil_attributes
			document.cascade_callbacks(:save){false}
		end

		#def assign_parent_details
			## call on order.
			## this can be called on any implementing object.
			## then the validations can be done.
		#end

		## so for eg, it will call this method.
		## and do it on the children.
		## if anything is defined at all.
		## so it will get set on the children.

		## what i want to do is this
		## call a function called validate
		## if there is a created_by_user
		## so for order it is there.
		## then on its children, do nothing.
		## just set the created by user on all its nested attributes.
		## currently held by organization id.
		## its actually correct its only on the top level objects
		## one option is to have the test with but it does not have that
		## so we need a def which takes the current_user
		## and also the currently held by organization id.
		## if it is defined, then it is ignored.

		def validate_nested
			#puts "Came to validate nested in class: #{self.class.name}"
			self.class.attribute_set.each do |virtus_attribute|
				if virtus_attribute.primitive.to_s == "Array"
					if virtus_attribute.respond_to? "member_type"
						class_name = virtus_attribute.member_type.primitive.to_s
						unless class_name == "BasicObject"
							## this is because you have not typified versions
							## and are storing it as a hash.
							unless self.send(virtus_attribute.name).blank?
								#puts "attribute name is: #{virtus_attribute.name.to_s}"
								self.send(virtus_attribute.name).each do |arr|
									#puts "validating: #{virtus_attribute.name.to_s}"
									#we don't validate owners inside nested.

									arr.skip_owners_validations = true if arr.respond_to? :skip_owners_validations
									unless arr.is_a? Hash
										arr.validate_nested
										unless arr.valid?
											self.errors.add(virtus_attribute.name.to_sym,arr.errors.full_messages)
											#error_messages.flatten
										end
									end
									
								end
							end
						end
					end
				end
			end
			#puts "errors are:"
			#puts self.errors.full_messages
		end

		def new_record?
			begin
				self.class.find(self.id.to_s)
				false
			rescue
				true
			end
		end

		def object_exists?(obj_class,id)
			begin
				obj_class.constantize.find(id)
			rescue
				false
			end
		end

		def nullify_nil_attributes
			self.attributes.keys.each do |attribute|
				self.send(attribute.to_s + "=",nil) if self.send(attribute).blank?
			end
		end

		## cascades the given hook to all nested elements.
		## @param[callbacks] symbol : eg :save, :find
		## in this concern, add this cascade_Callback(:whatever)
		## to the relevant hook, and it will automatically propagage to the nested elements.
		## eg:
		## before_save do |document|
		## 	  document.cascade_callbacks(:before_save)
		## end
		## so basically the same thing as is in the hook is passed
		## as the parameters.
		## you can hook it into a before_save call.
		## or whatever call you want, just pass callback
		## currently this has only been hooked into before_save
		def cascade_callbacks(callback)
			#puts " ----- DOING CASCADE CALLBACKS ----------- #{self.class.name}"
			self.class.attribute_set.each do |virtus_attribute|
				if virtus_attribute.primitive.to_s == "Array"
					if virtus_attribute.respond_to? "member_type"
						class_name = virtus_attribute.member_type.primitive.to_s
						unless class_name == "BasicObject"
							## this is because you have not typified versions
							## and are storing it as a hash.
							unless self.send(virtus_attribute.name).blank?
								#puts "attribute name is: #{virtus_attribute.name.to_s}"
								self.send(virtus_attribute.name).each do |arr|
									#puts "arr is: #{arr}"
									#puts "callback si: #{callback}"
									unless arr.is_a? Hash
										arr.run_callbacks(callback)
									end
								end
							end
						end 
					end
				end
			end
		end

		## @param[User] current_user : the current user
		## @called_from : 
		## 1.base_controller_concern, in the after_find callback invocations, as a block
		## 2.search_controller in #type_selector and #search
		## allows customization of the current record based on the user
		## is overriden in report, order.
		## @return[nil]
		def apply_current_user(current_user)

		end

		## @param[User] a user
		## @return[Boolean] true : if the user or its organization are present in the owner_ids of the current record, provied that the current record responds_to owner ids., false in any other eventuality.
		## @called_from : generally from the overriden apply_current_user invocations in different models.
		def belongs_to_user?(user)
			if self.respond_to? :owner_ids
				((self.owner_ids.include? user.id.to_s) || (self.owner_ids.include? user.organization.id.to_s))
			else
				false
			end
		end

		

		## @return[nil]
		## will return nothing
		## will just add the names of the attributes that have changed
		## to each attribute in self.
		## current_user
		## first determine who owns the report.
		## so for each object ->
		## organization of current user , known.
		## if he owns, it , or is the organization -> he can change
		## pass in the parent's organization also.
		def determine_changed_attributes(instance)

			params_list = []
			resource_name = self.class.name.split("::")[-1].downcase
			
			self.class.permitted_params.each do |k|
				if k.is_a? Hash
					if k.keys[0].to_s == resource_name
						params_list = k[resource_name.to_sym]
					end
				end
			end

			if params_list.blank?
				params_list = self.class.permitted_params
			end

			params_list.map!{|c|
				if c.is_a? Hash
					c.keys[0]
				else
					c 
				end
			}

		
			self.changed_attributes = []
			self.class.attribute_set.select{|c| 
								
				next unless params_list.include? c.name.to_sym

				# if it is blank ignore it.
				next if instance.send(c.name).nil?


				if c.primitive.to_s == "Array"
					if c.respond_to? "member_type"
						if c.member_type.primitive.to_s == "BasicObject"
							#self.plain_array_attributes << c
							#rule out nil
							if ((instance.send(c.name).blank?) || (self.send(c.name).blank?))
								unless ((instance.send(c.name).blank?) && (self.send(c.name).blank?))
									self.changed_attributes << c.name
								end
							else
								self.changed_attributes << c.name unless (instance.send(c.name).sort == self.send(c.name).sort)
							end
						else
							
							if ((self.send(c.name).blank?) || (instance.send(c.name).blank?))

								## if they are not equal, then changed.
								unless ((self.send(c.name).blank?) && (instance.send(c.name).blank?))

									self.changed_attributes << c.name

								end

							else
							
								self.send(c.name).each_with_index {|val,key|
									val.determine_changed_attributes(instance.send(c.name)[key])
									## pass this backwards.
									if val.changed_attributes.size > 0
										self.changed_attributes << c.name
									end
								}

							end
						end
					else
						#self.non_array_attributes << c
						unless ((self.send(c.name).blank?) && (instance.send(c.name).blank?))

							self.changed_attributes << c.name unless (instance.send(c.name) == self.send(c.name))								

						end
						
					end
				else
					#self.non_array_attributes << c
					unless ((self.send(c.name).blank?) && (instance.send(c.name).blank?))

						self.changed_attributes << c.name unless (instance.send(c.name) == self.send(c.name))								

					end
				end
			}
		end

		## call this before save in all the top level objects.
		def cascade_id_generation(organization_id)
			
			#puts "DOING CASCADE ID GENERATION self class is : #{self.class.name}, and org id: #{organization_id}"
			
			#if self.class.name =~ /category/i
			#	puts "it is a category and organization id incoming is: #{organization_id}"
			#end

			if self.class.name =~ /organization/i 
				self.assign_id_from_name(nil)
			else
				org_id = nil
				## if an organization id was already passed in .
				## use it.
				org_id = organization_id unless organization_id.blank?
				## if the name is blank, then what will you do.
				## this is useful when 
				## otherwise try to determine it.
				if org_id.blank?
					if self.respond_to? :created_by_user
						org_id = self.created_by_user.organization.id.to_s
					else
						raise("no organization specified") if organization_id.blank?
						org_id = organization_id
					end
				end
				self.assign_id_from_name(org_id)
				self.class.attribute_set.each do |virtus_attribute|
					if virtus_attribute.primitive.to_s == "Array"
						if virtus_attribute.respond_to? "member_type"
							class_name = virtus_attribute.member_type.primitive.to_s
							unless class_name == "BasicObject"
								## set the id , and call cascade on it.
								if virtus_attribute.name =~ /item/i
									puts "org id while going for item is: #{org_id}"
								end
								self.send("#{virtus_attribute.name}").each do |obj|
									unless obj.is_a? Hash
										if obj.respond_to? :cascade_id_generation
											obj.cascade_id_generation(org_id)
										end
									end
								end
							end
						end
					end
				end
			end
		end

	end

	module ClassMethods

	    def additional_attributes_for_json
	    	if defined? @json_attributes
	    		@json_attributes
	    	else
	    		[]
	    	end
	    end
		
	end

end
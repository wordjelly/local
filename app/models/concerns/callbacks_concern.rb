module Concerns::CallbacksConcern

	extend ActiveSupport::Concern

	included do 
		include ActiveModel::Validations
  		include ActiveModel::Validations::Callbacks

  		###############################################################
  		##
  		##
  		## validate nested -> before_validation
  		## by then any before_validation on the order leve
  		## will have passed.
  		## that is why it doesn't work.
  		##
  		##
  		###############################################################
		validate :validate_nested
		## cascade_id valid -> triggering.
		## that is the issue.
		## 
		## so i want cascade_id_generation to run after all the before_validations are done.
		## this will be the final skip
		## won't it.
		## they are added later.
		## so why 
		## either you do validate nested
		## or you cascade validation callbacks.
		## you don't do both.
		before_validation do |document|	
			document.assign_current_user
		end
		
		before_save do |document|
			document.nullify_nil_attributes
			document.cascade_callbacks(:save){false}
		end

		## should be set after_find
		## 

		## @called_from : before_validation
		## current_user is defined in owners_concern
		## current_user is set in the created_by_user= override method.
		def assign_current_user
			user_to_consider = nil
			if self.respond_to? :created_by_user
				## load the created by user after find ?
				## why not.
				## it can be overwritten.
				user_to_consider = (self.current_user || self.created_by_user)
			else
				user_to_consider = self.current_user
			end
			unless user_to_consider.blank?
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
										#puts "arr class is: #{arr.class.name.to_s}"
										if arr.respond_to? :current_user
											arr.current_user = user_to_consider
										end
									end
								end
							end
						end
					end
				end
			end
		end	

		def validate_nested(vars={})
			t1 = Time.now
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
										unless arr.is_a? Array
											unless arr.valid?
												if self.respond_to? :name
													self.errors.add(virtus_attribute.name.to_sym,(arr.errors.full_messages + [name]).flatten)
												else
													self.errors.add(virtus_attribute.name.to_sym,arr.errors.full_messages)
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
			t2 = Time.now
			if((t2 - t1).in_milliseconds) > 15
				puts "total time for validate nested in&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& #{self.class.name} :#{(t2 - t1).in_milliseconds}"
			end
		end

		def new_record?
			if self.newly_added == nil
				begin
					if RequestStore.store[self.id].blank?
						RequestStore.store[self.id] = self.class.find(self.id.to_s)
					end
					self.newly_added = false
					false
				rescue
					self.newly_added = true
					true
				end
			else
				self.newly_added
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

		## i can hook created by user.

		## @param[User] current_user : the current user
		## @called_from : 
		## 1.base_controller_concern, in the after_find callback invocations, as a block
		## 2.search_controller in #type_selector and #search
		## allows customization of the current record based on the user
		## is overriden in report, order.
		## @return[nil]
		def apply_current_user(current_user)

			#self.search_options ||= []			
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
		
		def cascade_id_generation(organization_id)
			if !self.validations_to_skip.blank?
				return if self.validations_to_skip.include? "cascade_id_generation"
			end
			
			if self.class.name =~ /organization/i 
				self.assign_id_from_name(nil)
				self.class.attribute_set.each do |virtus_attribute|
					if virtus_attribute.primitive.to_s == "Array"
						if virtus_attribute.respond_to? "member_type"
							class_name = virtus_attribute.member_type.primitive.to_s
							unless class_name == "BasicObject"
								## set the id , and call cascade on it.
								if virtus_attribute.name =~ /item/i
									#puts "org id while going for item is: #{org_id}"
								end
								self.send("#{virtus_attribute.name}").each do |obj|
									unless obj.is_a? Hash
										if obj.respond_to? :cascade_id_generation
											obj.cascade_id_generation(self.id.to_s)
										end
									end
								end
							end
						end
					end
				end
			else
				if self.class.name =~ /receipt/i
					#puts "class is: receipts"
					#puts "organization id is: #{organization_id}"
				end
				org_id = nil
				## if an organization id was already passed in .
				## use it.
				org_id = organization_id unless organization_id.blank?
				## if the name is blank, then what will you do.
				## this is useful when 
				## otherwise try to determine it.
				if org_id.blank?
					if self.respond_to? :created_by_user
						#puts "self class name is: #{self.class.name.to_s}"
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
								
								self.send("#{virtus_attribute.name}").each do |obj|
									
									unless obj.is_a? Hash
										if obj.respond_to? :cascade_id_generation
											obj.cascade_id_generation(org_id)
										end
									else
										
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
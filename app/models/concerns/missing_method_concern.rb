## THIS CONCERN HAS TO BE THE LAST INCLUDED CONCERN
## IN THE CONCERNS OF ANY MODEL.
module Concerns::MissingMethodConcern

	extend ActiveSupport::Concern

	included do 

		validate :validate_nested

		before_save do |document|
			document.nullify_nil_attributes
			document.cascade_callbacks(:save){false}
		end

		def validate_nested
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
										
									arr.validate_nested
									unless arr.valid?
										self.errors.add(virtus_attribute.name.to_sym,arr.errors.full_messages)
										#error_messages.flatten
									end
									
									#puts arr.errors.full_messages.to_s
									
								end
							end
						end
					end
				end
			end
			
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

		## call this before save in all the top level objects.
		def cascade_id_generation(organization_id)
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
								self.send("#{virtus_attribute.name}").each do |obj|
									obj.cascade_id_generation(org_id)
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
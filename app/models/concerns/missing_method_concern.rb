## THIS CONCERN HAS TO BE THE LAST INCLUDED CONCERN
## IN THE CONCERNS OF ANY MODEL.
module Concerns::MissingMethodConcern

	extend ActiveSupport::Concern

	included do 
		include ActiveModel::Validations
  		include ActiveModel::Validations::Callbacks

		## so we seperate the concerns.

		###############################################################
		##
		##
		## THESE ARE SET IN THE FILE 
		## config/initializers/hash.rb
		## a special method is monkey_patched into the ruby hash class
		## to compare to hashes
		## this is called from the base_controller_concern in the update action.
		##
		##
		###############################################################
		## Array -> names of changed attributes, as symbols.
		attr_accessor :changed_attributes
		## Array -> names of array attributes, whose sizes have changed, as symbols
		attr_accessor :changed_array_attribute_sizes

		## the previous size of all the array attribute
		## hash (key -> attribute name -> value : integer(size))
		attr_accessor :prev_size

		## the new size of all the array attribute
		## hash (key -> attribute name, value -> integer(size))
		attr_accessor :current_size

		##single attribute -> can be true(if it was newly added) or blank.
		## intended to be used with 
		attr_accessor :newly_added

		attr_accessor :attributes_were

		attr_accessor :attributes_are
  	
	    ## initialize these if they are nil.
	    ## At this stage.
	    ## so the defaults.	
	  	## expected an array of method names as strings
		## which are to be skipped
		## can be used to skip particular validations.
		## if blank, will be ignored.
		attr_accessor :validations_to_skip

	    before_validation do |document|
	      ["changed_attributes","changed_array_attribute_sizes"].each do |arr|
	        if document.send(arr).nil?
	          document.send("#{arr}=",[])
	        end
	      end
	      ["prev_size","current_size"].each do |hsh|
	        if document.send(hsh).nil?
	          document.send("#{hsh}=",{})
	        end
	      end
	      if document.newly_added.nil?
	        document.newly_added = true
	      end
	    end

	    ## so this i can put in missing method ?
		## but it has no access to that.
		after_find do |document|
			document.cascade_callbacks(:find)
			document.newly_added = false
			document.changed_attributes ||= []
			document.changed_array_attribute_sizes ||= []
			## same old shit here.
			document.prev_size ||= {}
			document.current_size ||= {}
		end

		## @return[String] the name of the embedded object class
		## @called_from : config/initializers/hash.rb
		def get_attribute_class(attribute_name_as_string)
			class_name = nil
			self.class.attribute_set.each do |virtus_attribute|
				if virtus_attribute.name.to_s == attribute_name_as_string
					if virtus_attribute.primitive.to_s == "Array"
						#puts "is an array"
						if virtus_attribute.respond_to? "member_type"
							class_name = virtus_attribute.member_type.primitive.to_s
							break
						end
					end
				end
			end
			class_name
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
				#puts "doing attribute: #{virtus_attribute.name}"
				if virtus_attribute.primitive.to_s == "Array"
					#puts "is an array"
					if virtus_attribute.respond_to? "member_type"
						class_name = virtus_attribute.member_type.primitive.to_s
						unless class_name == "BasicObject"
							#puts "its not a base object"
							## this is because you have not typified versions
							## and are storing it as a hash.
							#puts "reports size is:---------------"
							#puts self.reports.size.to_s
							unless self.send(virtus_attribute.name).blank?

								#puts "attribute name not blank is: #{virtus_attribute.name.to_s}"
								self.send(virtus_attribute.name).each do |arr|
									#puts "arr is: #{arr}"
									#puts "callback si: #{callback}"
									unless arr.is_a? Hash
										unless arr.is_a? Array
											arr.run_callbacks(callback)
										end
									end
								end
							end
						end 
					end
				end
			end
		end

		## @param[Boolean] filter_permitted_params : defaults to false, if true will only keep permitted params in the returned attributes.
		## @return[Hash] deep_attributes
		def deep_attributes(filter_permitted_params=false,include_blank_attributes=true)
			attributes = {}
			## top level attributes
			permitted_params_list = []
			## if the second element is a hash, with the name of the class.
			### then take that
			## otherwise, take the top level itself.
			## today i want to finish
			if self.class.permitted_params[1].is_a? Hash
				
				if self.class.name.to_s =~ /#{self.class.permitted_params[1].keys[0]}/i
					permitted_params_list = self.class.permitted_params[1].values

				end
			else
				permitted_params_list = self.class.permitted_params
			end

			permitted_params_list.flatten!

			permitted_params_list.map!{|c|
				if c.is_a? Hash
				#	puts "got hash."
					c = c.keys[0]
				#	puts "c becomes: #{c}"
				else
					#puts "no hash."
				end 
				c
			}

			#puts "permitted params list is:"
			
			#puts permitted_params_list.to_s
			
			#exit(1)

			
			self.class.attribute_set.each do |virtus_attribute|
				#puts "doing attribute: #{virtus_attribute.name}"
				if filter_permitted_params == true
					next unless permitted_params_list.include? virtus_attribute.name.to_s.to_sym 
				end
				if virtus_attribute.primitive.to_s == "Array"
					#puts "is an array"
					attributes[virtus_attribute.name.to_s] = []
					if virtus_attribute.respond_to? "member_type"
						class_name = virtus_attribute.member_type.primitive.to_s
						
						self.send(virtus_attribute.name).each do |obj|
							
							unless class_name == "BasicObject"

								attributes[virtus_attribute.name.to_s] << obj.deep_attributes(filter_permitted_params,include_blank_attributes)

							else
								## so its a hash.
								attributes[virtus_attribute.name.to_s] << obj.to_s

							end
						end
						
					end
				else
					attributes[virtus_attribute.name.to_s] = self.send(virtus_attribute.name)
					
				end
			end
			attributes["id"] = self.id.to_s
			if include_blank_attributes.blank?
				attributes.delete_if{|key,value|
					value.blank?
				}
			end 
			attributes
		end

	end

	## sort out remaining issues of interfaces
	## so lets start with this. 
	## and why its polling multiple times.
	## sort that
	## and also the response returning
	## run tests for pf lab interface basically.

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
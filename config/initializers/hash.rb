class ::Hash
	## return[Hash]
	## @called_From : base_controller_concern: #get_model_params: before returning attributes.
	## @working : it will recursively walk down the entire hash, and if there is any scalar array which contains empty elements, for eg: ["".""], it will remove those elements. the purpose is to get rid of empty arrays that rails sends, when we use placeholder fields in forms.
    def deep_clean_arrays
		self.keys.each do |k|
			if self[k].is_a? Hash
				self[k] = self[k].deep_clean_arrays
			elsif self[k].is_a? Array
				if self[k][0].is_a? Hash
					self[k] = self[k].map{|c|
						c.deep_clean_arrays
					}
				else
					self[k] = self[k].reject{|c| c.empty?}
				end
			else

			end
		end
		self
	end

	## @param[Elasticsearch::Model] object :  an object 	implementing ELasticsearch::Model and MissingMethodsConcern.
	## @working : every key in the current hash is iterated. 
	## if the value of the key is nil , we go to the next key.
	## if the object does not respond to a method by the name of the key, we go to the next key.
	## what this means is that if an incoming value is nil, the value existing in the object will prevail as default.
	## if the object's value is blank for this key, then the incoming value is assigned, and the key is added to the changed attributes of the object.
	## for hash, and scalar values, the implementation is pretty simple, wherein if the object has blank for the key, then the incoming value is assigned, if not blank, then in case of hash, we call changed attributes on that hash value, passing in the same value from the object.
	## in case of array, if the size is different, we say that the top level array attribute has changed.
	## if the size is the same, each value is compared.
	## in case of scalar attributes, they are compared by converting to string and stripping,
	## check the tests, under test/models/hash.rb to see how this works.
	## @called_from
	## @return : nil
	def assign_attributes(object,assign=true)
		return unless object.respond_to? :changed_attributes
		return unless object.respond_to? :changed_array_attribute_sizes
		object.changed_attributes ||= []
		object.changed_array_attribute_sizes ||= []
		object.prev_size ||= {}
		object.current_size ||= {}

		self.keys.each do |k|
			
			next if self[k].nil?
			next unless object.respond_to? k
			if self[k].is_a? Hash
				if object.send(k).blank?
					object.send("#{k}=",self[k])
					object.changed_attributes << k
				else
					self[k].assign_attributes(object.send(k),assign)
					object.changed_attributes << k unless object.send(k).changed_attributes.blank?
				end 
			elsif self[k].is_a? Array
				
				object.prev_size[k] = object.send(k).blank? ? 0 : object.send(k).size
				object.current_size[k] = self[k].size
				
				if object.send(k).blank?
					#if(k.to_s == "recipients")
					#	puts "got it as blank"
					#end
					object.send("#{k}=",self[k]) unless assign.blank?
					unless self[k].blank?
						object.changed_attributes << k
						object.changed_array_attribute_sizes << k
					end

				elsif (object.send(k).size != self[k].size)
					#if(k.to_s == "recipients")
					#	puts "size is different"
					#end
					self[k].each_with_index{|val,key|
						
						break if (key == object.send(k).size) 
						if val.is_a? Hash
							#puts "val is: #{val}"
							#so the existing object did not have it.
							val.assign_attributes(object.send(k)[key],assign)
							object.changed_attributes << k unless object.send(k)[key].changed_attributes.blank?
						else
							object.changed_attributes << k unless val == object.send(k)[key]
							object.send(k)[key] = val unless assign.blank?
						end
					}

					if object.prev_size[k] < object.current_size[k]
						self[k].each_with_index{|val,key|
							if key >= object.prev_size[k]
								cls = object.get_attribute_class(k)
								object.send(k).push(cls.constantize.new(val)) 
								object.send(k)[-1].newly_added = true
							end
						}
					elsif object.prev_size[k] > object.current_size[k]
						#puts "got k as: #{k}, with prev size being greater"
						#so now there are no receipts.
						#so what is the problem.
						#the receipts were deleted.
						#exit(1)
						object.send("#{k}=",object.send(k)[0,object.current_size[k]])
					end

					object.changed_attributes << k
					object.changed_array_attribute_sizes << k
				
				else
					#if (k.to_s == "recipients")
					#	puts "size is the same, it is something else."
					#end
					#puts "size is the same"
					self[k].each_with_index{|val,key|
						#puts "val is what #{val.class.name}"
						if val.is_a? Hash
							#puts "val is: #{val}"
							val.assign_attributes(object.send(k)[key],assign)
							
							#puts object.send(k)[key].changed_attributes

							object.changed_attributes << k unless object.send(k)[key].changed_attributes.blank?
						else
							#puts "val is something else"
							object.changed_attributes << k unless val == object.send(k)[key]
							object.send(k)[key] = val unless assign.blank?
						end
					}
				end

				#if k.to_s == "recipients"
				#	puts "------------------------------------------------------------"
				#end
				
			else
				#puts "scalar value current #{object.send(k)}, and incoming: #{self[k]}"
				if (object.send(k).to_s.strip == self[k].to_s.strip)

				else
					object.send("#{k}=",self[k]) unless assign.blank?
					object.changed_attributes << k
				end
			end
		end
		object.changed_attributes.uniq!
		object.changed_array_attribute_sizes.uniq!
	end
end
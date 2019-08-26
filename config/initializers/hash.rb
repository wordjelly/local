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
end
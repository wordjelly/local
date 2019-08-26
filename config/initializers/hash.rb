class ::Hash
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
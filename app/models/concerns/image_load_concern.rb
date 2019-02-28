module Concerns::ImageLoadConcern

	extend ActiveSupport::Concern

	included do 

		attr_accessor :images
		
		after_find do |document|
			document.load_images
		end

		##find an image/ images with this parent id.
		##and add them to an images array. 
		def load_images
			puts "came to load images ----------- "
			self.images = Image.search(
				{
					:query => {
						:term => {
							:parent_id => {
								:value => self.id.to_s
							}
						}
					}
				}
			) || []
		end

	end

end
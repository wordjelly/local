module Auth::Concerns::ImageLoadConcern

	extend ActiveSupport::Concern

	included do 

		attr_accessor :images
		
		after_initialize do |document|
			document.load_images
		end

		##find an image/ images with this parent id.
		##and add them to an images array. 
		def load_images
			puts "came to load images ----------- "
			self.images = Auth::Image.search(
				{
					:term => {
						:parent_id => {
							:value => self.id.to_s
						}
					}
				}
			) || []
		end

	end

end
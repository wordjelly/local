module Concerns::ImageLoadConcern

	extend ActiveSupport::Concern

	included do 

		attr_accessor :images
		
		after_find do |document|
			document.load_images
		end

		## it is because the 

		##find an image/ images with this parent id.
		##and add them to an images array. 
		def load_images
			search_results = Image.search(
				{
					:query => {
						:term => {
							:parent_id => {
								:value => self.id.to_s
							}
						}
					}
				}
			)
			self.images ||= []
			unless search_results.response.hits.hits.blank?
				search_results.response.hits.hits.each do |hit|
					self.images << Image.find(hit["_id"])
				end
			else
				
			end

		end

	end


	## @return[Boolean] true/false : if the we have to show the upload image form button
	## false by default, so you will never get the option to upload images
	## by default.
	def show_image_upload
		false
	end

	## then there is the plain card.
	## but first this.

end
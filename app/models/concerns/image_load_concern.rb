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
				#puts "no images detected for this resource ------ "
			end

			#self.images.each do |ig|
			#	puts " -------- Image --------- "
			#	puts ig.attributes.to_s
			#end

		end

	end

end
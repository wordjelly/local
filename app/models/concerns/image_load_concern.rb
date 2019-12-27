module Concerns::ImageLoadConcern

	extend ActiveSupport::Concern

	included do 

		YES = 1
		NO = -1

		attr_accessor :images
		## add this to permitted params.
		attribute :images_allowed, Integer, default: NO

		if defined? @permitted_params
        	if ((@permitted_params[1].is_a? Hash) && (self.class.name.to_s =~ /#{@permitted_params[1].keys[0]}/i))
  			  	@permitted_params[1] = @permitted_params[1] + [:images_allowed]
  		  	else
          		@permitted_params = @permitted_params + [:images_allowed]
        	end
      	else
  			@permitted_params = [:images_allowed]
  		end

  		## so its in the permitted params
  		## only the index.
  		## that we have to see.

		after_find do |document|
			document.images ||= []
			document.load_images if (images_allowed == YES)
		end

		## it is because the 

		##find an image/ images with this parent id.
		##and add them to an images array. 
		def load_images
			t1 = Time.now
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
			
			unless search_results.response.hits.hits.blank?
				search_results.response.hits.hits.each do |hit|
					self.images << Image.find(hit["_id"])
				end
			else
				
			end
			t2 = Time.now
			puts "load images from class: #{self.class.name} takes: #{(t2-t1).in_milliseconds}"

		end

	end


	## @return[Boolean] true/false : if the we have to show the upload image form button
	## false by default, so you will never get the option to upload images
	## by default.
	def show_image_upload
		false
	end

	## we try to load images for every object.
	## we an block this for certain objects
	## but this is taking so long.
	
end
require 'elasticsearch/persistence/model'
## include in any model that needs to be given a location.
module Concerns::LocationConcern
  	extend ActiveSupport::Concern

  	included do
  		attr_accessor :latitude
  		attr_accessor :longitude
  		attr_accessor :address
  		attr_accessor :spot_tag
  		attr_accessor :organization_location_id
      attr_accessor :created_location
      attr_accessor :created_location_errors

  		if defined? @permitted_params
        if ((@permitted_params[1].is_a? Hash) && (self.class.name.to_s =~ /#{@permitted_params[1].keys[0]}/i))
  			  @permitted_params[1] = @permitted_params[1] + [:latitude, :longitude, :address, :spot_tag, :organization_location_id]
  		  else
          @permitted_params = @permitted_params + [:latitude, :longitude, :address, :spot_tag, :organization_location_id]
        end
      else
  			@permitted_params = [:latitude, :longitude, :address, :spot_tag, :organization_location_id]
  		end
  
      if defined? @json_attributes
        @json_attributes = @json_attributes + [:created_location, :created_location_errors]
      else
        @json_attributes = [:created_location, :created_location_errors]
      end

      before_save do |document|
        #puts "triggering the add location callback ------------------------------------------"
        #exit(1)
        document.add_location
      end

  	end

  
  	def add_location
      #okay so the organization must have a location
      #if he wants to choose the lab locations -> then those should be shown to him.
      #which should not be too difficult.
      #to choose
      #so an accessor choose_location
      #puts " ========== CAME TO ADD LOCATION =================== "
      #exit(1)
      #puts "the the latitude :#{self.latitude} and longitude: #{self.longitude} is:"
  		unless ((self.latitude.blank?) && (self.longitude.blank?))
  			self.created_location = Geo::Location.new
  			self.created_location.created_by_user = self.created_by_user
  			self.created_location.latitude = self.latitude
  			self.created_location.longitude = self.longitude
  			self.created_location.model_id = self.id.to_s
  			self.created_location.model_class = self.class.name.to_s
        self.created_location.assign_id_from_name
  			self.created_location.save
        self.created_location_errors = self.created_location.errors.full_messages
  		else 
  			unless self.address.blank?
  				#puts "the address is not blank."
          self.created_location = Geo::Location.new
	  			self.created_location.created_by_user = self.created_by_user
	  			self.created_location.address = address
	  			self.created_location.model_id = self.id.to_s
	  			self.created_location.model_class = self.class.name.to_s
	  			self.created_location.assign_id_from_name
          self.created_location.save
          self.created_location_errors = self.created_location.errors.full_messages
  			else
  				unless organization_location_id.blank?
  					organization_location = self.created_by_user.locations[0]
  					self.created_location = Geo::Location.new(address: organization_location.address, latitude: organization_location.latitude, longitude: organization_location.longitude, model_id: self.id.to_s, model_class: self.class.name, created_by_user: self.created_by_user)
  					self.created_location.assign_id_from_name
            self.created_location.save
            self.created_location_errors = self.created_location.errors.full_messages
  				end
  			end
  		end
  	end

end
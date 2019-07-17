module Concerns::Diagmodule::Status::OutsourceConcern

	extend ActiveSupport::Concern

	## i should do blocks also properly

  	included do
  	
  		attribute :required, Integer
  		
  		attribute :origin, Hash
  	
  		attribute :performing_organization_id, String

  		attribute :category, String

  		@permitted_params = [
  			:required,
  			:performing_organization_id,
  			:category,
  			{:origin => [:lat,:lon]} 
  		]

  		@index_properties = {
  			:required => {
  				type: 'integer'
  			},
  			:origin => {
  				type: 'geo_point'
  			},
  			:category => {
  				type: 'keyword'
  			},
  			:performing_organization_id => {
  				type: 'keyword'
  			}
  		}

  	end

end
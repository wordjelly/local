require 'elasticsearch/persistence/model'

## include in any model that needs to be given a location.
module Concerns::LocationConcern
  	extend ActiveSupport::Concern

  	included do
  	
  		include Elasticsearch::Persistence::Model

  		attribute :location_id, String, mapping: {type: 'keyword'}

  	end

end
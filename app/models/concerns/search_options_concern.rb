module Concerns::SearchOptionsConcern
  	extend ActiveSupport::Concern

  	included do
      ## populated via MissingMethodsConcern#apply_current_user
  	  ##attribute :search_options, Array, mapping: {type: 'keyword'}, default: []
  	  attr_accessor :search_options
  	end

end
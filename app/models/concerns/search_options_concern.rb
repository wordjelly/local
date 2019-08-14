module Concerns::SearchOptionsConcern
  	extend ActiveSupport::Concern

  	included do
      ## populated via MissingMethodsConcern#apply_current_user
  		attribute :search_options, [], default: []
  	end

end
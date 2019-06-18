module Concerns::OrderConcern

	extend ActiveSupport::Concern

	included do 
		
		attribute :reports, Array[Hash]

		attribute :patient_id, String, mapping: {type: 'keyword'}

		## this can be populated as well.
		attribute :requirements, Array[Hash] 

		attribute :payments, Array[Hash]

		attribute :local_item_group_id

		before_save do |document|
			document.update_requirements
		end

	end

	def update_requirements

	end

end
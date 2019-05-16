require 'elasticsearch/persistence/model'

module Concerns::BarcodeConcern
  	extend ActiveSupport::Concern

  	included do
  	
  		include Elasticsearch::Persistence::Model
  		
  		attribute :barcode, String, mapping: {type: 'keyword'}

  		attr_accessor :skip_barcode_uniqeness

  		validate :barcode_is_unique, :if => Proc.new{|c| c.skip_barcode_uniqeness.blank?}


	  	## this will happen automatically in update
	  	## just before update, in the set_model call.
	  	## so update will automatically not try to create a barcode.
	  	after_find do |document|
	  		document.skip_barcode_uniqeness = true
	  	end

	  	## so this can be skipped in the update action.
	  	## by setting it through edit ?
	  	## no, after_find, set it.
	  	## simple callback.
	  	def barcode_is_unique
	  		if self.respond_to? :barcode
				unless self.barcode.blank?
					b = Barcode.new
					b.id = document.barcode
					begin
						b.save(op_type: 'create')
					rescue
						self.errors.add(:barcode,"this barcode has already been used")
					end
				end
			end
	  	end

  	end


end
require 'elasticsearch/persistence/model'

module Concerns::BarcodeConcern
  	extend ActiveSupport::Concern

  	included do
  	
  		include Elasticsearch::Persistence::Model

  		attribute :barcode, String, mapping: {type: 'keyword'}
  		attr_accessor :barcode_object

  		attr_accessor :skip_barcode_uniqeness

  		validate :barcode_is_unique, :if => Proc.new{|c| c.skip_barcode_uniqeness.blank?}

  		## best option would be to delete that barcode.
  		## and not complicate it.
  		## in case the save failed.
	  	## this will happen automatically in update
	  	## just before update, in the set_model call.
	  	## so update will automatically not try to create a barcode.
	  	after_find do |document|
	  		document.skip_barcode_uniqeness = true
	  		#tranfer.
	  		#that means create an item_transfer.
	  		#
	  	end

	  	## fastest way is to write a test
	  	## for anything.
	  	## doesn't matter.
	  	## this will execute only after_create
	  	## as there is no barcode object otherwisel.
	  	after_save do |document|
	  		document.delete_barcode unless document.errors.blank?
	  	end

	  	## so this can be skipped in the update action.
	  	## by setting it through edit ?
	  	## no, after_find, set it.
	  	## simple callback.
	  	## you are creating a barcode, and then what if the 
	  	## the record is not created,
	  	## what happens to the barcode ?
	  	## you save it with the id of the item trying to be created
	  	## uniqueness is assured.
	  	## provided such an item does not already exist?
	  	## the barcode will have to updated on successfully saving
	  	## the document, with its identity and index.
	  	## if that is not assured, then this will screw up.
	  	## before save check 
	  	## on save, complete, what happens?
	  	## it updates that barcode, with the word success.
	  	## so it is saved -> does not update
	  	## someone else can then use that barcode.
	  	## that is the drawback.
	  	## and you have to change that.
	  	## that's life
	  	## and if you want to check again , what will you do?
	  	## nothing you are told to update the barcode?
	  	## we will have to write an update script.
	  	## we want to update, the barcode.
	  	## let it throw the error.
	  	## then try an update for a registered id, which does 
	  	## not have this id on it.
	  	## otherwise in the after_save update it.
	  	## as the registered id.
	  	def barcode_is_unique
	  		if self.respond_to? :barcode
				unless self.barcode.blank?
					self.barcode_object = Barcode.new
					self.barcode_object.id = self.barcode
					begin
						self.barcode_object.save(op_type: 'create')
					rescue
						self.errors.add(:barcode,"this barcode has already been used")
					end
				end
			end
	  	end

	  	## We can call this explicitly ?
	  	## not required.
	  	def delete_barcode
	  		self.barcode_object.delete unless self.barcode_object.blank?
	  	end

	  	def transfer
	  		
	  		response = Inventory::ItemTransfer.search({
	  			size: 1,
	  			query: {
	  				barcode: self.barcode
	  			}
	  		})
	  		
	  		previous_item_transfer = nil
	  		response.results.hits.hits.each do |hit|
	  			previous_item_transfer = Inventory::ItemTransfer.find(hit["_id"])
	  		end

	  		if previous_item_transfer.nil?
	  			
	  		else

	  		end

	  		it = Inventory::ItemTransfer.new
	  		## then we have the previous item transfer.
	  		## if its from a user of a different organization
	  		## we cannot do anything.
	  		## it will not allow what?
	  		## this goes into authorization.
	  		## we need the previous item transfer.
	  		## if a previous itemtransfer does not exist.
	  		## then it doesnt matter really.
	  		## from user, we don't know.
	  		## doesn't matter.
	  		## only if that is a different organization user.
	  		## so bare transfers are only for transactions.
	  		## nothing else.
	  		## or for patients
	  		## or for orders.
	  		## we transfer, all items
	  		## if its a transaction
	  		## or a bare item type transfer also can be done.

	  	end

  	end


end
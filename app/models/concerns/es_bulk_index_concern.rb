module Concerns::EsBulkIndexConcern
  extend ActiveSupport::Concern

  included do
  	cattr_accessor :bulk_items
  	cattr_accessor :total_items_bulked
  	## in case some multi search items were there.
  	cattr_accessor :search_results

  	self.bulk_items = []
  	self.total_items_bulked = 0

	##override in implementing model.
	def self.bulk_size
	  5000
	end

	def self.reset_bulk_items
		self.bulk_items = []
	end

	## the total number of items that have been sent to es
	## through the bulk mechanism.
	def self.add_total
		self.total_items_bulked += self.bulk_items.size
	end

	def self.do_bulk
		#puts "called do bulk"
		#puts "bulk items are:"
		#puts bulk_items.to_s
		add_total
	  	#puts "building bulk items"
	  	if bulk_items.blank?
	  		#puts "nothing to bulk"
	  		return
	  	end

	  	## so we have to gather the multisearch requests.
	  	search_requests = []
	  	bulk_items.delete_if { |e|
	  		if e.is_a? Hash
		  		unless e[:search].blank?
					search_requests << e
					true	  			
		  		end
	  		end
	  	}
	  	
	  	bulk_request = bulk_items.map{|c|

	  		unless c.is_a? Hash
				c = {
	  					index:  { _index: c.class.index_name, _id: c.id, _type: c.class.document_type, data: c.as_json }
	  				}	  			
	  		end

	  		c
	  	}

	  	#puts "making bulk call"
	  	resp = gateway.client.bulk body: bulk_request unless bulk_items.blank?
	  	#we need to return the response of the bulk call.
	  	#problem is that this is not reliable.
	  	#
	  	#puts "search requests are=====================>:"
	  	#puts search_requests.to_s
		unless search_requests.blank?

			multi_response = gateway.client.msearch body: search_requests 
			#puts "the search results are:"
			#puts multi_response.to_s
			self.search_results = multi_response["responses"]
		end
		if total_items_bulked.size > 0
			#puts "completed bulk of #{bulk_size} items."
			#puts "total bulked : #{total_items_bulked}"
			#puts "#{Time.now.to_i}"
		end
		reset_bulk_items
	end

	def self.add_bulk_item(item)
		#puts "item time: #{Time.now.to_i}"
	  	if total_items = self.bulk_items.size
	  		bulk_items << item if total_items < self.bulk_size
	  		do_bulk if total_items >= self.bulk_size
	  	end
	end

	## call this method at the end somewhere in the place where you are adding bulk items.
	def self.flush_bulk
		do_bulk
	end

  end

end
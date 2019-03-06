require 'elasticsearch/persistence/model'
class Order

	include Elasticsearch::Persistence::Model
	
	index_name "pathofast-orders"

	attr_accessor :patient_name

	attribute :patient_id, String

	## these are the template reports.
	## we need the ids.
	attribute :template_report_ids, Array

	## items are the tubes that got assigned.
	attribute :item_ids, Array

	attribute :report_name, String

	attribute :patient_test_ids, Array

	attribute :patient_report_ids, Array

	## so item requirements is going to be like what exactly ?
	## the item id will point to that.
	## it will carry th test ids.

	attribute :item_requirements, Hash


	attr_accessor :patient
	attr_accessor :reports
	attr_accessor :items

	## adding or removing an item group.
	## if you want to ad items by means of an item group
	attr_accessor :item_group_id
	attr_accessor :item_group_action

	## if you want to add individual items.
	## array of objects.
	attr_accessor :item_type
	attr_accessor :item_type_index
	attr_accessor :item_id
	attr_accessor :item_id_action

	attr_accessor :item_types
		
=begin

=end

	settings index: { 
	    number_of_shards: 1, 
	    number_of_replicas: 0,
	    analysis: {
		      	filter: {
			      	nGram_filter:  {
		                type: "nGram",
		                min_gram: 2,
		                max_gram: 20,
		               	token_chars: [
		                   "letter",
		                   "digit",
		                   "punctuation",
		                   "symbol"
		                ]
			        }
		      	},
	            analyzer:  {
	                nGram_analyzer:  {
	                    type: "custom",
	                    tokenizer:  "whitespace",
	                    filter: [
	                        "lowercase",
	                        "asciifolding",
	                        "nGram_filter"
	                    ]
	                },
	                whitespace_analyzer: {
	                    type: "custom",
	                    tokenizer: "whitespace",
	                    filter: [
	                        "lowercase",
	                        "asciifolding"
	                    ]
	                }
	            }
	    	}
	  	} do
	    mappings dynamic: 'true' do
		    indexes :item_requirements, type: 'object'
		end

	end

	validates_presence_of :patient_id	
	## takes the template report ids, and creates reports from that, as well as cloning all tests associated with those reports.
	before_save do |document|
		puts "came to create patient reports"
		document.create_patient_reports
	end

	def add_report(report_id)

	end

	def create_patient_reports
		self.reports ||= []
		self.template_report_ids.each do |report_id|
			report = Report.find(report_id)
			self.patient_report_ids << report.clone(self.patient_id).id.to_s
			self.patient_test_ids << report.test_ids
			self.patient_test_ids.flatten!

			## these reports are the cloned reports.
			self.reports << report
			set_item_requirements
		end
	end

	def barcoded_tube_has_space?(filled_amount, already_occupied, additional_requirement)

	end

	## @param[String] report_id : the report id that you want to accomodate in this order.
	## @return[Hash] true/false :true if the existing item_requirements can accomodate it and 
	def accomodate(report)
		result = false
		## an accomodation address map for each requirement.
		## if it could be accomodated.
		## if a new tube had to be created for it?
		## if a new tube had to be created, then we have to break saying could not be accomodated.
		## and thereafter.
		report.item_requirements.keys.each do |ir|
			if self.item_requirements[ir.item_type].blank?
				result = false
				break
				## add the tube.
			else
				requirement_accomodated = false
				self.item_requirements[ir.item_type].map{|item_requirement,key|
					unless item_requirement[:barcode].blank?
						if barcoded_tube_has_space?(item_requirement[:filled_amount],item_requirement[:amount],ir.amount)
							## add it to the amount, and add this report id also.
							requirement_accomodated = true
							## add it.
							## add the thing to the current tube.
						end
					else
						## check if the ir.amount + item_requirement[amount] > 100, in which case it cannot be accomodated, so we dont' do anthing.
					end
				}
				## if could not be accomodated -> add a new tube.
				## basically that's the idea.
				
			end

		end	
	end

	def exists?(report_id)
		self.template_report_ids.include? report_id
	end

	## so now if it says cannot accomodate, then tubes have to be added.
	## in that case, if the order status is past collection, it should decide.
	
	def add_remove_reports
		self.template_report_ids ||= []
		params[:template_report_ids].each do |report_id|
			unless exists?(report_id)
				report = Report.find(report_id)
				self.patient_report_ids << report.clone(self.patient_id).id.to_s
				self.patient_test_ids << report.test_ids
				self.patient_test_ids.flatten!
				self.reports << report
				accomodate(report)
			else
				puts "this report already exists."
			end
		end
		## now check which of the existing reports have been removed.
		## in that case, we just knock of those report ids, from the item_requirements, i.e we mark them as removed.
		## nothing more is needed to be done.
	end

	## then the patient id.


	def set_item_requirements
		self.item_requirements ||= {}
		self.reports.each do |report|
			puts "iterating report: #{report}"
			report.load_item_requirements
			puts "its item requirements are:"
			puts report.item_requirements
			report.item_requirements.each do |ir|
				puts "doing item requirement: #{ir}"
				if self.item_requirements[ir.item_type].blank?
					
					## we will also have to define some kind of bare minimum dead amount.
					## in any tube.
					## for eg if three things, are there
					## each needs 10.
					## so suppose the current requirement amount on that tube is 20.
					## and we have a filled amoutn of 40.
					## we have to check if this tube, can accomodate this report or not.
					## we have to see so, can_be_accomodated?
					## if yes, then we add it to those tubes
					## otherwise, we add additional indexes, of the required tubes.
					self.item_requirements[ir.item_type] = [{amount: ir.amount, optional: ir.optional, barcode: nil, filled_amount: 0}]
					
				else

					puts "item type exists in the item_requirements"

					self.item_requirements[ir.item_type][-1][:amount] += ir.amount
						
					puts "incrementing the amount."
					puts self.item_requirements.to_s

					if 	self.item_requirements[ir.item_type][-1][:amount] > 100

						k = self.item_requirements[ir.item_type][-1][:amount]

						self.item_requirements[ir.item_type] << {amount: (k - 100), optional: ir.optional}

						self.item_requirements[ir.item_type][-2][:amount] = 100 
					end
				end
			end	
		end 
	end

	def other_order_has_barcode?(barcode)
		response = Order.search({
			query: {
				term: {
					item_ids: barcode
				}
			}
		})
		mash = Hashie::Mash.new response 
		return true if hash.hits.hits.size > 0
		
	end


	def add_barcodes(params)
		params["item_requirements"].keys.each do |id|
			type = params["item_requirements"]["type"]
			index = params["item_requirements"]["index"]
			barcode = params["item_requirements"]["barcode"]
			unless barcode.blank?
				unless self.item_requirements[type].blank?
					self.item_requirements[type][index.to_i]["barcode"] = barcode unless other_order_has_barcode?(barcode)
				end
			end
		end
	end
	
	def load_patient
		self.patient = Patient.find(self.patient_id)
		self.patient_name = self.patient.name
	end

	def load_reports
		self.reports ||= []
		self.patient_report_ids.each do |patient_report_id|
			self.reports << Report.find(patient_report_id)
		end	
	end

	def load_items
		self.items ||= []
		self.item_ids.each do |item_id|
			self.items << Item.find(item_id)
		end
	end	
	
end
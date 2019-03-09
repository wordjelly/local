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
	#before_save do |document|
	#	puts "came to create patient reports"
	#	document.create_patient_reports
	#end

	after_save do |document|
		## adds the reports to the items themselves.
		## or removes them thereof.
	end

	def add_report(report_id)

	end

=begin
	def create_patient_reports
		self.reports ||= []
		self.template_report_ids.each do |report_id|
			report = Report.fhttps://guides.rubyonrails.org/testing.html#functional-tests-for-your-controllersind(report_id)
			self.patient_report_ids << report.clone(self.patient_id).id.to_s
			self.patient_test_ids << report.test_ids
			self.patient_test_ids.flatten!

			## these reports are the cloned reports.
			self.reports << report
			set_item_requirements
		end
	end
=end

	def barcoded_tube_has_space?(filled_amount, already_required, additional_requirement)
		return (filled_amount - already_required) >= additional_requirement
	end

	## adds a new tube for a particular report.
	def add_new_tube(item_requirement,report)
		

		self.item_requirements[item_requirement.item_type] ||= []
		self.item_requirements[item_requirement.item_type] << 
		{required_amount: item_requirement.amount, optional: item_requirement.optional, barcode: nil, filled_amount: 0, report_ids: [report.id.to_s]}
		
		#puts self.item_requirements[item_requirement.item_type]

	end

	## @param[ItemRequirement] ir
	## @param[Integer] key 
	## @param[String] report_id
	def add_report_id_to_item_requirement(ir,key,report_id)
		self.item_requirements[ir.item_type][key]["report_ids"] ||= []
		self.item_requirements[ir.item_type][key]["report_ids"] << report_id
	end

	## @param[String] report_id : the report id that you want to accomodate in this order.
	## @return[Hash] true/false :true if the existing item_requirements can accomodate it and 
	def accomodate(report)
		report.item_requirements.each do |ir|
			#puts "iterating report item req"
			#puts ir.to_s
			#puts "self item requirements are:"
			#puts self.item_requirements.to_s
			#exit(1)
			if self.item_requirements[ir.item_type].blank?
				puts "adding new tube----------- for item type: #{ir.item_type}"
				add_new_tube(ir,report)
				puts "item requirements becomes:"
				puts self.item_requirements.to_s
			else
				requirement_accomodated = false

				self.item_requirements[ir.item_type].each_with_index{|item_requirement,key|

					unless item_requirement["barcode"].blank?
						if barcoded_tube_has_space?(item_requirement["filled_amount"],item_requirement["required_amount"],ir.amount)
							
							self.item_requirements[ir.item_type][key]["required_amount"] += ir.amount
							
							add_report_id_to_item_requirement(ir,key,report.id.to_s)

							requirement_accomodated = true
							
						end
					else
						#puts "ir is:"
						#puts ir.to_s
						#puts "item requirement is:"
						#puts item_requirement.to_s
						unless (ir.amount + item_requirement["required_amount"] > 100)

							self.item_requirements[ir.item_type][key]["required_amount"]+=ir.amount

							add_report_id_to_item_requirement(ir,key,report.id.to_s)

							requirement_accomodated = true

						end
					end
				}
				if requirement_accomodated == false
					add_new_tube(ir,report)
				end
			end

		end	
	end

	def exists?(report_id)
		self.template_report_ids.include? report_id
	end

	## so now if it says cannot accomodate, then tubes have to be added.
	## in that case, if the order status is past collection, it should decide.
	def add_remove_reports(params)
		puts "params are:"
		self.template_report_ids ||= []
		self.reports ||= []
		unless params[:template_report_ids].blank?
			params[:template_report_ids].each do |report_id|
				unless exists?(report_id)
					self.template_report_ids << report_id
					report = Report.find(report_id)
					self.patient_report_ids << report.clone(self.patient_id).id.to_s
					self.patient_test_ids << report.test_ids
					self.patient_test_ids.flatten!
					self.reports << report
					report.load_item_requirements
					accomodate(report)
				else
					puts "this report already exists."
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
		self.errors.add(:item_ids, "This barcode #{barcode} has already been assigned to order id #{response.results.first.id.to_s}") if response.results.size > 0
		return true if response.results.size > 0
		
	end


	def add_barcodes(params)
		unless params["item_requirements"].blank?
			params["item_requirements"].keys.each do |id|
				
				type = params["item_requirements"][id]["type"]
				
				index = params["item_requirements"][id]["index"]
				
				barcode = params["item_requirements"][id]["barcode"]
				
				filled_amount = params["item_requirements"][id]["filled_amount"]
				
				unless barcode.blank?
					
					unless self.item_requirements[type].blank?
						self.item_requirements[type][index.to_i]["barcode"] = barcode unless other_order_has_barcode?(barcode)
						self.item_ids ||= []
						self.item_ids << barcode
						self.item_requirements[type][index.to_i]["filled_amount"] = filled_amount unless filled_amount.blank?
					else
						puts "this type does not exist in the self item requirements."
					end

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
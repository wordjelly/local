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

	def create_patient_reports
		self.reports ||= []
		self.template_report_ids.each do |report_id|
			report = Report.find(report_id)
			self.patient_report_ids << report.clone(self.patient_id).id.to_s
			self.patient_test_ids << report.test_ids
			self.patient_test_ids.flatten!

			self.reports << report
			set_item_requirements
		end
	end

	def set_item_requirements
		self.item_requirements ||= {}
		self.reports.each do |report|
			report.load_item_requirements
			report.item_requirements.each do |ir|

				if self.item_requirements[ir.item_type].blank?

					self.item_requirements[ir.item_type] = [{amount: ir.amount, optional: ir.optional}]
				
				else

					self.item_requirements[ir.item_type][-1][:amount] += ir.amount
					
					if 	self.item_requirements[ir.item_type][-1][:amount] > 100

						k = self.item_requirements[ir.item_type][-1][:amount]

						self.item_requirements[ir.item_type] << {amount: (k - 100), optional: ir.optional}

						self.item_requirements[ir.item_type][-2][:amount] = 100 
					end
				end
			end	
		end 
	end

	
	def load_patient
		#begin
			self.patient = Patient.find(self.patient_id)
			puts "patient is: #{patient}"
			self.patient_name = self.patient.name
		#rescue

		#end
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
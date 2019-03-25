require 'elasticsearch/persistence/model'
class Report

	include Elasticsearch::Persistence::Model
	include Concerns::StatusConcern

	index_name "pathofast-reports"

	attribute :template_report_id, String, mapping: {type: "keyword"}

	attribute :test_ids, Array

	attr_accessor :test_name
	attr_accessor :test_id_action
	attr_accessor :test_id
	attribute :tests, Array

	attribute :patient_id, String, mapping: {type: 'keyword'}

	attribute :name, String

	attribute :price, Float
	validates :price, numericality: true


	attribute :item_requirement_ids, Array

	attr_accessor :item_requirement_name
	attr_accessor :item_requirement_id_action
	attr_accessor :item_requirement_id
	attribute :item_requirements, Array

	attr_accessor :item_requirements_grouped_by_type
	attr_accessor :patient

	after_find do |document|
		document.load_patient
		document.load_tests
		document.load_item_requirements
	end

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

	    mapping do
	      
		    indexes :name, type: 'keyword', fields: {
		      	:raw => {
		      		:type => "text",
		      		:analyzer => "nGram_analyzer",
		      		:search_analyzer => "whitespace_analyzer"
		      	}
		    }
		end

	end
	
	
	before_save do |document|
		if document.test_id_action
			if document.test_id_action == "add"
				document.test_ids << document.test_id
			elsif document.test_id_action == "remove"
				document.test_ids.delete(document.test_id)
			end
		end
		
		if document.item_requirement_id_action
			if document.item_requirement_id_action == "add"
				document.item_requirement_ids << document.item_requirement_id
				
			elsif document.item_requirement_id_action == "remove"
				document.item_requirement_ids.delete(document.item_requirement_id)
			end
		end
	end


	#attribute :required_image_ids, Array
	## what kind of pictures are necessary
	## before releasing this report ?
	## rapid kit image
	## blood grouping card image
	## optional images of test_tubes
	## graph image for hba1c

	## what type of items does it need?
	## for eg : item type (red top tube/ orange top/ golden top, uses 5%, min amount, and max amount.)
	## this will be called a report_item_requirement.
	## will be an item type, a amount, optional
	## priority.
	

	def clone(patient_id,order_id)
		
		patient_report = Report.new(self.attributes.except(:id).merge({patient_id: patient_id, template_report_id: self.id.to_s}))
		#puts "after merging patient report:"
		#puts patient_report.attributes.to_s
		#exit(1)
		
		patient_report.test_ids = []
		
		self.test_ids.each do |test_id|
			unless test_id.blank?
				t = Test.find(test_id)
				patient_test = t.clone(patient_id)
				patient_report.test_ids << patient_test.id.to_s
			end
		end

		patient_report.save
		## create a status, of the payment.

		Status.add_bill(patient_report,order_id)
		patient_report

	end

	## as long as there is no status that says collection completed
	## the 
	def can_be_cancelled?
		status_completed = self.statuses.select{|c|
			c.text_value == Status::COLLECTION_COMPLETED
		}
		status_completed.size == 0
	end

	## so we add some status like this
	## for the test.

	def load_patient	
		unless self.patient_id.blank?
			self.patient = Patient.find(self.patient_id)
		end
	end

	def load_tests
		self.tests ||= []
		self.test_ids.each do |tid|
			self.tests << Test.find(tid) unless tid.blank?
		end
		self.tests.map{|c| c.report_id = self.id.to_s}
		puts "the test report ids are:"
		self.tests.map{|c| puts c.report_id}
	end

	def load_item_requirements
		puts "Came to load item requirements."
		self.item_requirements_grouped_by_type = {}
		self.item_requirements ||= []
		self.item_requirement_ids.each do |iid|
			unless iid.blank? 
				ireq = ItemRequirement.find(iid)
				if self.item_requirements_grouped_by_type[ireq.item_type]
				else
					self.item_requirements_grouped_by_type[ireq.item_type] = []
				end
				self.item_requirements_grouped_by_type[ireq.item_type] << ireq
				self.item_requirements << ireq
			end
		end
		self.item_requirements.map{|c| c.report_id = self.id.to_s }
	end

	def build_query
		queries = [{
			filter: {
				query: {
					match_all: {}
				}
			}
		}]

		self.attributes.each do |attr|
			if self.send(attr).class.to_s == "Array"
				unless self.send(attr).blank?
					if self.send(attr)[0] == "*"
						queries << {
							exists: {
								field: attr.to_sym.to_s
							}
						}
					else
						queries << {
							terms: {
								attr.to_s.to_sym => self.send(attr)
							}
						}
					end
				end
			elsif self.send(attr).class.to_s == "String"
				if self.send(attr) == "*"
					queries << {
						exists: {
							field: attr.to_sym.to_s
						}
					}
				else
					queries << {
						term: {
							attr.to_s.to_sym => self.send(attr)
						}
					}
				end
			elsif self.send(attr).class.to_s =~ /Float|Integer/
				queries << {
					range: {
						attr.to_s.to_sym => {
							gte: self.send(attr),
							lte: self.send(attr)
						}
					}
				}
			end
		end	
		queries
	end

end
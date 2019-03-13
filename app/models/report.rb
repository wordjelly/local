require 'elasticsearch/persistence/model'
class Report

	include Elasticsearch::Persistence::Model

	index_name "pathofast-reports"

	attribute :template_report_id, String

	attribute :test_ids, Array

	attr_accessor :test_name
	attr_accessor :test_id_action
	attr_accessor :test_id
	attribute :tests, Array

	attribute :patient_id, String

	attribute :name, String

	attribute :price, Float

	attribute :item_requirement_ids, Array

	attr_accessor :item_requirement_name
	attr_accessor :item_requirement_id_action
	attr_accessor :item_requirement_id
	attribute :item_requirements, Array

	attr_accessor :item_requirements_grouped_by_type



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
	

	def clone(patient_id)
		
		patient_report = Report.new(self.attributes.merge({patient_id: patient_id, template_report_id: self.id.to_s}))
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
		patient_report

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


end
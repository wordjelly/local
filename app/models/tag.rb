require 'elasticsearch/persistence/model'
class Tag

	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::CallbacksConcern

	index_name "pathofast-tags"

	attribute :name, String, mapping: {type: 'keyword', copy_to: "search_all"}
	validates_presence_of :name

	attribute :description, String, mapping: {type: 'keyword', copy_to: "search_all"}

	EMPLOYEE_TAG = "employee"
	COLLECTION_TAG = "collection"
	HISTORY_TAG = "history"
	INFORMATION_TAG = "information"
	TAG_TYPES = [EMPLOYEE_TAG,COLLECTION_TAG,HISTORY_TAG]
	YES = 1
	NO = -1
	NORMAL = "normal"
	ABNORMAL = "abnormal"
	HISTORY = "history"
	RANGE_TYPES = [NORMAL,ABNORMAL,HISTORY]

	attribute :tag_type, String
	#validates_presence_of :tag_type

	attribute :history_options, Array, mapping: {type: 'keyword', copy_to: "search_all"}

	attribute :selected_option, String, mapping: {type: 'keyword'}

	attribute :text_history_response, String, mapping: {type: 'keyword'}

	attribute :numerical_history_response, Float, mapping: {type: 'float'}

	attribute :selected_option_must_match_history_options, Integer, mapping: {type: 'integer'}, default: NO

	attribute :option_must_be_chosen, Integer, mapping: {type: 'integer'}, default: NO

	####################################################
	##
	##
	## these are fixed values inside the ranges.
	##
	##
	####################################################
	attribute :min_history_val, Float, mapping: {type: 'float'}

	attribute :max_history_val, Float, mapping: {type: 'float'}

	attribute :text_history_val, String, mapping: {type: 'keyword'}

	###################################################
	##
	##
	## 
	##
	##
	####################################################
	## the range value itself, i.e of the test
	attribute :min_range_val, Float, mapping: {type: 'float'}

	attribute :max_range_val, Float, mapping: {type: 'float'}

	attribute :text_range_val , String, mapping: {type: 'keyword'}

	## if this range is selected in the presence of multiple tags.
	attribute :combined_with_history_tag_ids, Array, mapping: {type: 'keyword'}

	## this can be normal/abnormal/history
	attribute :range_type, String, mapping: {type: 'keyword'}
	
	attribute :inference, String, mapping: {type: 'text'}
	validates_presence_of :inference, :if => Proc.new{|c| c.range_type == ABNORMAL }



	attribute :comment, String, mapping: {type: 'text'}

	attribute :reference, String, mapping: {type: 'text'}

	attribute :grade, String, mapping: {type: 'text'}

	attribute :count, Integer, mapping: {type: 'integer'}


    mapping do
	    indexes :name, type: 'keyword', fields: {
	      	:raw => {
	      		:type => "text",
	      		:analyzer => "nGram_analyzer",
	      		:search_analyzer => "whitespace_analyzer"
	      	}
	    },
	    copy_to: "search_all"
	end

	
	before_validation do |document|
		document.assign_id_from_name(nil)
	end

	## do you want to first embed it in test
	## and write the test and range validations next.
	## then the order range assessment.

	## USED IN SOME TESTS AND RAKE TASKS
	## @return[Hash] tags 
	def self.create_default_employee_roles
		tags = {}
		["Pathologist","Technician","Supervisor"].each do |role_name|
			t = Tag.new(name: role_name, tag_type: EMPLOYEE_TAG, skip_owners_validations: true)
			t.save
			unless t.errors.full_messages.blank?
				puts t.errors.full_messages.to_s
				exit(1)
			end
			tags[t.id.to_s] = t
		end
		tags
	end

	def self.index_properties
		{
	    	name: {
	    		type: 'keyword',
	    		fields: {
		    			:raw => {
		    				:type => "text",
				      		:analyzer => "nGram_analyzer",
				      		:search_analyzer => "whitespace_analyzer"
		    			}
		    		}
	    	},
	    	description: {
	    		type: 'text'
	    	},
	    	tag_type: {
	    		type: 'keyword'
	    	},
	    	history_options: {
	    		type: 'keyword'
	    	},
	    	selected_option: {
	    		type: 'keyword'
	    	},
	    	selected_option_must_match_history_options: {
	    		type: 'integer'
	    	},
	    	option_must_be_chosen: {
	    		type: 'integer'
	    	},
	    	text_history_response: {
	    		type: 'keyword'
	    	},
	    	numerical_history_response: {
	    		type: 'float'
	    	},
	    	min_history_val: {
	    		type: 'float'
	    	},
	    	max_history_val: {
	    		type: 'float'
	    	},
	    	text_history_val: {
	    		type: 'keyword'
	    	},
	    	min_range_val: {
	    		type: 'float'
	    	},
	    	max_range_val: {
	    		type: 'float'
	    	},
	    	text_range_val: {
	    		type: 'keyword'
	    	},
	    	combined_with_history_tag_ids: {
	    		type: 'keyword'
	    	},
	    	range_type: {
	    		type: 'keyword'
	    	},
	    	inference: {
	    		type: 'keyword'
	    	},
	    	comment: {
	    		type: 'keyword'
	    	},
	    	reference: {
	    		type: 'keyword'
	    	},
	    	grade: {
	    		type: 'keyword'
	    	},
	    	count: {
	    		type: 'integer'
	    	}

	    }
	end


	def self.permitted_params
		[
			:id, 
			{   :tag => 
				[
					:description,
					:name, 
					:tag_type, 
					:selected_option, 
					:selected_option_must_match_history_options, 
					:option_must_be_chosen, 
					{:history_options => []}, 
					:text_history_response, 
					:numerical_history_response, 
					:min_history_val, 
					:max_history_val, 
					:text_history_val, 
					:min_range_val, 
					:max_range_val, 
					:text_range_val, 
					{:combined_with_history_tag_ids => []},
					:range_type, 
					:inference,
					:comment, 
					:reference, 
					:grade, 
					:count 
				]
			}
		]

	end	


	######################################################3
	##
	##
	## HISTORY HELPERS
	##
	##
	######################################################
	def is_history_tag?
		self.tag_type == HISTORY_TAG
	end

	## @Called_from : test#history_provided?
	def history_provided?
		return true unless is_history_tag?
		!self.selected_option.blank?
	end

	def is_normal?
		self.range_type == NORMAL
	end

	def is_abnormal?
		self.range_type == ABNORMAL
	end

	def is_history?
		self.range_type == HISTORY
	end

end
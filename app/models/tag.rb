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
	SMOKER = "smoker"
	NORMAL = "normal"
	ABNORMAL = "abnormal"
	HISTORY = "history"
	RANGE_TYPES = [NORMAL,ABNORMAL,HISTORY]

	attribute :tag_type, String
	#validates_presence_of :tag_type

	## required inside range
	## just a bson object id, that is set on the tag
	## as more than one tag of the same primary tag can 
	## be added inside the range.
	## @set_in : range#add_tags
	attribute :nested_id, String, mapping: {type: 'keyword'}

	attribute :history_options, Array, mapping: {type: 'keyword', copy_to: "search_all"}

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
	## uses the self#nested_id attribute defined above.
	attribute :combined_with_history_tag_ids, Array, mapping: {type: 'keyword'}

	## this can be normal/abnormal/history
	attribute :range_type, String, mapping: {type: 'keyword'}
	
	attribute :inference, String, mapping: {type: 'text'}
	validates_presence_of :inference, :if => Proc.new{|c| c.range_type == ABNORMAL }

	attribute :comment, String, mapping: {type: 'text'}

	attribute :reference, String, mapping: {type: 'text'}

	attribute :grade, String, mapping: {type: 'text'}

	attribute :count, Integer, mapping: {type: 'integer'}

	## so more than one can be picked
	## we have to see
	## this will be picked by the range.
	## it has the age and all in it.
	## this is the just the range value
	## the range picking will proceed anyways. unabated.
	attribute :picked, Integer, mapping: {type: 'integer'}

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
	    	},
	    	picked: {
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

	def pick
		#puts "setting tag as picked: #{self.nested_id}"
		self.picked = YES
	end


	def unpick
		self.picked = NO
	end



	######################################################3
	##
	##
	## HISTORY HELPERS
	##
	##
	######################################################
	def get_biological_interval
		if is_numerical_range?
			self.min_range_val.to_s + "-" + self.max_range_val.to_s
		elsif is_text_range?
			self.text_range_val.to_s		
		end
	end

	def is_history_tag?
		self.range_type == HISTORY_TAG
	end



	def is_required?
		puts "is the tag required"
		puts "is it a history tag: #{is_history_tag?}"
		puts "option must be selected: #{self.option_must_be_chosen}"
		is_history_tag? && self.option_must_be_chosen == YES
	end



	## @Called_from : test#history_provided?
	def history_provided?
		#puts "came to check history provided?"
		puts "is history tag: #{is_history_tag?}"
		#puts "selected option: #{self.selected_option}"
		puts "text history response is: #{self.text_history_response}" 
		return true unless is_history_tag?
		self.history_answered?
	end

	def is_normal?
		#puts "came to check if tag is normal: #{self.range_type}"
		k = self.range_type == NORMAL
		#puts "Returninig k : #{k}"
		k
	end

	def is_abnormal?
		self.range_type == ABNORMAL
	end

	def is_history?
		self.range_type == HISTORY
	end

	def text_history_answered?
		!self.text_history_response.blank?
	end

	def numerical_history_answered?
		!self.numerical_history_response.blank?
	end

	def history_answered?
		puts "Came to check text history answered"
		puts self.text_history_answered?.to_s
		puts "Came to check numerical history answered"
		puts self.numerical_history_answered?.to_s
		self.text_history_answered? || self.numerical_history_answered?
	end

	def no_combinations_defined?
		self.combined_with_history_tag_ids.blank?
	end

	def is_numerical_range?
		!self.min_range_val.blank? && !self.max_range_val.blank?
	end

	def is_text_range?
		!self.text_range_val.blank?
	end

	## @called_from : range#pick_range
	def combination_satisfied?(matching_tags)
		self.combined_with_history_tag_ids.map{|c|
			matching_tags.include? c.id.to_s
		}.uniq == "[true]"
	end

	## @called_from : range#pick_range
	def history_satisfied?(history_tag)
		puts "history tag is &&&&&&&&&&&& "
		puts history_tag.to_s
		if !history_tag.numerical_history_response.blank?
			puts "numerical history response not blank"
			return history_tag.numerical_history_response.to_f.between?(self.min_history_val.to_f,self.max_history_val.to_f)
		elsif !history_tag.text_history_response.blank?
			puts "text history response not blank."
			return history_tag.text_history_response.to_s == (self.text_history_val.to_s)
		end
		false
	end

	## @called_from : range#pick_range
	def test_value_satisfied?(test_value_numeric, test_value_text)
		if !test_value_numeric.blank?
			puts "test value numeric is not blank: #{test_value_numeric}"
			puts "self min range val is: #{self.min_range_val}"
			puts "Self max range val is: #{self.max_range_val}"
			test_value_numeric.between?(self.min_range_val,self.max_range_val)
		elsif !test_value_text.blank?
			test_value_text == self.text_range_val
		end
	end

	def is_picked?
		self.picked == YES
	end


end
require 'elasticsearch/persistence/model'
class Tag

	## the id of the history tag, which tells how many days since the last menstrual period.
	## used in pathofast: rake : preprocess_pathofast_reports
	## basically i had to add this as a template_tag_id for all the reports that had a trimester specific range tag.
	## this is the id mentioned inside vendor/pathofast_report_formats/history_tags
	LMP_TAG_ID = "tags:days_since_lmp"

	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::FormConcern
	include Concerns::CallbacksConcern

	index_name "pathofast-tags"

	## so undefined will be in a tag
	## in this case, normal biological interval is not available and it should say that.

	## when no values are available for this age and sex
	attribute :undefined, Integer, mapping: {type: 'integer'}

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
	## CUSTOMIZATION TAGS ARE USED IN ORDERS.
	CUSTOMIZATION = "customization"
	
	PHLEBOTOMIST_VISIT = "home_visit"
	
	COURIER_VISIT = "courier_visit"
	
	PATIENT_VISIT_LAB = "patient_will_visit_lab"

	SAMPLE_WILL_BE_DELIVERED_TO_LAB = "sample_will_be_delivered_to_lab"



	RANGE_TYPES = [NORMAL,ABNORMAL,HISTORY,CUSTOMIZATION]

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

	## this has to be factored
	## also there is undefined.
	## for some ranges the values are undefined.
	## 
	attribute :max_range_val_unbound, Integer, mapping: {type: 'integer'}

	attribute :min_range_val_unbound, Integer, mapping: {type: 'integer'}

	attribute :text_range_val , String, mapping: {type: 'keyword'}

	## if this range is selected in the presence of multiple tags.
	## uses the self#nested_id attribute defined above.
	attribute :combined_with_history_tag_ids, Array, mapping: {type: 'keyword'}

	## this can be normal/abnormal/history
	attribute :range_type, String, mapping: {type: 'keyword'}
	
	attribute :inference, String, mapping: {type: 'text'}, default: " "
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

	###################################################
	##
	##
	## date related parameters.
	##
	##
	###################################################
	#yyyy-MM-dd'T'HH:mm:ss
	attribute :_date, DateTime, mapping: {type: 'date', format: "yyyy-MM-dd'T'HH:mm:ss.SSSZ"}
		
	attribute :completed_years_since_date, Integer, mapping: {type: 'integer'}

	attribute :completed_months_since_date, Integer, mapping: {type: 'integer'}

	attribute :completed_days_since_date, Integer, mapping: {type: 'integer'}

	attribute :completed_weeks_since_date, Integer, mapping: {type: 'integer'}

	## right so -> we do this before
	## before_validation.
	## if this is equal to: completed_years_since_date
	## then it will automatically assign the value of completed_years_since_date to numerical_history_response
	attribute :numerical_history_response_derived_from_attribute, String, mapping: {type: 'keyword'}



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
		#puts "self _date is: #{self._date.to_s}"
		document.assign_time_since_date unless document._date.blank?
	end

	## so we put that into the setup.
	## and also the template report ids?
	## so we will have to put them there.
	## and also their ids,
	## will have to be done.
	def assign_time_since_date
		#puts "came to assing time since date."
		t = DateTime.now
		self.completed_weeks_since_date = TimeDifference.between(_date, t).in_weeks.to_i
		self.completed_months_since_date = TimeDifference.between(_date, t).in_months.to_i
		self.completed_years_since_date = TimeDifference.between(_date, t).in_years.to_i
		self.completed_days_since_date = TimeDifference.between(_date, t).in_days.to_i
		self.numerical_history_response = self.send(self.numerical_history_response_derived_from_attribute) unless self.numerical_history_response_derived_from_attribute.blank?
	end

	## after this just the verify and finalize modalities are going to be pending. tomorrow i can finish the report formats, and check once more if all the interfacing is working.

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
	    	min_range_val_unbound: {
	    		type: 'integer'
	    	},
	    	max_range_val_unbound: {
	    		type: 'integer'
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
	    	},
	    	_date: {
	    		type: 'date',
	    		format: "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
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
					:max_range_val_unbound,
					:min_range_val_unbound,
					:text_range_val, 
					{:combined_with_history_tag_ids => []},
					:range_type, 
					:inference,
					:comment, 
					:reference, 
					:grade, 
					:count,
					:_date
				]
			}
		]

	end	

	def pick
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
	#####################################################
	def get_biological_interval
		if self.undefined == YES
			"-"
		else
			if is_numerical_range?
				if self.max_range_val_unbound == YES
					">=" + self.min_range_val.to_s
				elsif self.min_range_val_unbound == YES
					"<=" + self.min_range_val.to_s
				else
					self.min_range_val.to_s + "-" + self.max_range_val.to_s
				end
			elsif is_text_range?
				self.text_range_val.to_s		
			end
		end
	end

	def is_history_tag?
		self.range_type == HISTORY_TAG
	end

	def is_trimester_tag?
		self.name =~ /trimester/i
	end

	def is_required?
		#puts "is the tag required"
		#puts "is it a history tag: #{is_history_tag?}"
		#puts "option must be selected: #{self.option_must_be_chosen}"
		is_history_tag? && self.option_must_be_chosen == YES
	end



	## @Called_from : test#history_provided?
	def history_provided?
		#puts "came to check history provided?"
		#puts "is history tag: #{is_history_tag?}"
		#puts "selected option: #{self.selected_option}"
		#puts "text history response is: #{self.text_history_response}" 
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

	def is_customization?
		self.range_type == CUSTOMIZATION
	end

	def text_history_answered?
		!self.text_history_response.blank?
	end

	def numerical_history_answered?
		!self.numerical_history_response.blank?
	end

	def history_answered?
		#puts "Came to check text history answered"
		#puts self.text_history_answered?.to_s
		#puts "Came to check numerical history answered"
		#puts self.numerical_history_answered?.to_s
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
		puts "--------------------- INCOMING HISTORY TAG NUMERICAL HISTORY RESPONSE #{history_tag.numerical_history_response} , and our min history val: #{self.min_history_val} and max_history_val: #{self.max_history_val} -----------------"
		#puts history_tag.to_s
		if !history_tag.numerical_history_response.blank?
			#puts "numerical history response not blank and is: #{history_tag.numerical_history_response}"
			#puts "min history val is: #{self.min_history_val}, and max history val: #{self.max_history_val}"
			return history_tag.numerical_history_response.to_f.between?(self.min_history_val.to_f,self.max_history_val.to_f)
		elsif !history_tag.text_history_response.blank?
			#puts "text history response not blank and is: #{history_tag.text_history_response}"
			#puts "self text history val is: #{self.text_history_val}"
			return history_tag.text_history_response.to_s == (self.text_history_val.to_s)
		end
		false
	end

	## @called_from : range#pick_range
	def test_value_satisfied?(test_value_numeric, test_value_text)
		if !test_value_numeric.blank?
			if self.min_range_val_unbound == Tag::YES
				if test_value_numeric < self.max_range_val
					true
				else
					false
				end
			elsif self.max_range_val_unbound == Tag::YES
				if test_value_numeric >= self.min_range_val
					true
				else
					false
				end
				## but unbound, should affect the printed range.
			else
				if self.min_range_val <= test_value_numeric
					if test_value_numeric < self.max_range_val
						true
					else
						false
					end
				else
					false
				end
			end
		elsif !test_value_text.blank?
			test_value_text == self.text_range_val
		end
	end

	def is_picked?
		self.picked == YES
	end

	def summary_row(args={})
		'
			<tr>
				<td>' + self.name + '</td>
				<td><div class="edit_nested_object" data-id=' + self.unique_id_for_form_divs + '>Edit</div></td>
			</tr>
		'
	end

	## should return the table, and th part.
	## will return some headers.
	def summary_table_headers(args={})
		'''
			<thead>
	          	<tr>
	              	<th>Name</th>
			        <th>Options</th>
	          	</tr>
	        </thead>
		'''
	end


end
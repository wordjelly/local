require 'elasticsearch/persistence/model'

class Diagnostics::Range
	
	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	#include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::VersionedConcern
	include Concerns::FormConcern

	## select this, in a select form.
	GENDERS = ["Male","Female","Other"]
	DEFAULT_GENDER = "Not Selected"
	DEFAULT_TEXT_VALUE = "Not Entered"
	


	def fields_not_show_in_form
		["created_at","updated_at","public","currently_held_by_organization","created_by_user_id","owner_ids","min_age","max_age"]		
	end

	def customizations(root)
		root ||= self.class.name.classify.demodulize.underscore.downcase
		#puts "root is: #{root}"

		k = ApplicationController.helpers.select_tag(root + "[sex]" ,ApplicationController.helpers.options_for_select(GENDERS), {:class => "browser-default"})
		k += "<label>Select Gender</label>".html_safe

		{
			"sex" => k
		}
	end

	#########################################################
	##
	##
	## MIN AGE -> DEFINED BY FOUR UNITS, EACH OF WHICH WILL DEFAULT TO ZERO.
	##
	##
	#########################################################
	attribute :min_age_years, Integer, :default => 0
	attribute :min_age_months, Integer, :default => 0
	attribute :min_age_days, Integer, :default => 0
	attribute :min_age_hours, Integer, :default => 0

	#########################################################
	##
	##
	## MAX AGE -> DEFINED BY FOUR UNITS, EACH OF WHICH WILL DEFAULT TO ZERO.
	##
	##
	#########################################################
	attribute :max_age_years, Integer, :default => 0
	attribute :max_age_months, Integer, :default => 0
	attribute :max_age_days, Integer, :default => 0
	attribute :max_age_hours, Integer, :default => 0

	## this is not permitted, it is internally calcualted.
	attribute :min_age, Integer, default: 0
		
	## This is also not permitted but internally calculate.
	attribute :max_age, Integer, default: 0
	
	attribute :sex, String, default: DEFAULT_GENDER

	attribute :min_value, Float, :default => 0.0

	attribute :max_value, Float, :default => 0.0

	attribute :text_value, String, mapping: {type: 'keyword'}, default: DEFAULT_TEXT_VALUE

	attribute :grade, String, mapping: {type: 'keyword'}

	attribute :count, String, mapping: {type: 'keyword'}

	attribute :name, String, mapping: {type: 'keyword', copy_to: 'search_all'}

	attribute :machine, String, mapping: {type: 'keyword'}

	attribute :comment, String, mapping: {type: 'text'}

	attribute :kit, String, mapping: {type: 'keyword'}

	attribute :reference, String, mapping: {type: 'keyword'}

	## picked -> 1 (means this range satisfied the test value.)
	## picked -> -1 (default, does not satisfy.)
	attribute :picked, Integer, mapping: {type: 'integer'}, default: -1	

	## abnormal -> 1
	## normal -> -1
	attribute :is_abnormal, Integer, mapping: {type: 'integer'}, default: 1	

	attribute :is_default_range, Integer, mapping: {type: 'integer'}, default: -1

	attribute :inference, String, mapping: {type: 'text'}


	before_save do |document|
		document.set_min_and_max_age
	end
	###########################################################
	##
	##
	## VALIDATIONS AND CALLBACKS.
	##
	##
	###########################################################
	def set_min_and_max_age

		#puts "came to set min age"
		self.min_age = (self.min_age_years*365*24) + (self.min_age_months*31*24) + (self.min_age_days*24) + self.min_age_hours
		#puts "min age is:"
		#puts self.min_age

		self.max_age = (self.max_age_years*365*24) + (self.max_age_months*31*24) + (self.max_age_days*24) + self.max_age_hours
		#puts "max age is:"
		#puts self.max_age

	end

	def self.permitted_params
		[
			:id,
			:min_age_years,
			:min_age_months,
			:min_age_days,
			:min_age_hours,
			:max_age_years,
			:max_age_months,
			:max_age_days,
			:max_age_hours,
			:sex,
			:grade,
			:count,
			:inference,
			:comment,
			:is_abnormal,
			:text_value,
			:picked,
			:is_default_range,
			:inference,
			:min_value, 
			:max_value, 
			:name, 
			:machine, 
			:kit, 
			:reference,
			:min_age,
			:max_age
		]
	end

	def self.index_properties
		{
			min_age_years: {
				type: "integer"
			},
			min_age_months: {
				type: "integer"
			},
			min_age_days: {
				type: "integer"
			},
			min_age_hours: {
				type: "integer"
			},
			max_age_years: {
				type: "integer"
			},
			max_age_months: {
				type: "integer"
			},
			max_age_days: {
				type: "integer"
			},
			max_age_hours: {
				type: "integer"
			},
			sex: {
				type: "keyword"
			},
			grade: {
				type: "keyword"
			},
			count: {
				type: "float"
			},
			inference: {
				type: 'text'
			},
			comment: {
				type: 'text'
			},
			is_abnormal: {
				type: 'integer'
			},
			text_value: {
				type: 'text'
			},
			picked: {
				type: 'integer'
			},
			is_default_range: {
				type: 'integer'
			},
			inference: {
				type: 'text'
			},
			min_age: {
				type: 'integer'
			},
			max_age: {
				type: 'integer'
			}
    	}
    	
	end

	def pick_range
		self.picked = 1
	end

	###########################################################
	##
	## OVERRIDDEN FROM FORM CONCERN
	## what will you show in the form.
	## and that the tubes have been added or not.
	## what about multiple categories.
	##
	############################################################
	def summary_row(args={})
		'
			<tr>
				<td>' + self.min_age.to_s + '</td>
				<td>' + self.max_age.to_s + '</td>
				<td>' + self.sex + '</td>
				<td>' + self.min_value.to_s + '</td>
				<td>' + self.max_value.to_s + '</td>
				<td>' + (self.text_value || DEFAULT_TEXT_VALUE) + '</td>
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
	              <th>Min Age</th>
	              <th>Max Age</th>
	              <th>Sex</th>
	              <th>Min Value</th>
	              <th>Max Value</th>
	              <th>Text Value</th>
	              <th>Options</th>
	          </tr>
	        </thead>
		'''
	end

	## @return[String] a combination of the 
	def get_display_name
		""
	end

end 
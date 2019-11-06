require 'elasticsearch/persistence/model'

class Diagnostics::Range
	
	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::VersionedConcern
	include Concerns::FormConcern
	include Concerns::CallbacksConcern

	# what if abnormal is not defined ?
	# 

	## select this, in a select form.
	MALE = "Male"
	FEMALE = "Female"
	OTHER = "Other"
	GENDERS = [MALE,FEMALE]
	DEFAULT_GENDER = "Not Selected"
	DEFAULT_TEXT_VALUE = "Not Entered"
	YES = 1
	NO = -1
	ABNORMAL = YES
	## THIS WILL GO WRONG ON MONTHS.
	## COMPLETELY WRONG.
	AGE_DAYS_MULTIPLIER = 24
	AGE_MONTHS_MULTIPLIER = 31*AGE_DAYS_MULTIPLIER
	AGE_YEARS_MULTIPLIER = 12*AGE_MONTHS_MULTIPLIER

	## ranges will cover only people between 0 hours and whatever hours are there in 120 years, we don't expect anyone to live beyond 120 years.
	MINIMUM_POSSIBLE_AGE_IN_HOURS = 0
	MAXIMUM_POSSIBLE_AGE_IN_HOURS = 120*AGE_YEARS_MULTIPLIER

	## it could be that a test is not applicable to males or females.

	def fields_not_show_in_form
		["created_at","updated_at","public","currently_held_by_organization","created_by_user_id","owner_ids","min_age","max_age"]		
	end

	def fields_not_to_show_in_form_hash(root="*")
		{
			"*" => ["created_at","updated_at","public","currently_held_by_organization","created_by_user_id","owner_ids","min_age","max_age","picked","normal_picked","active"],
			"order" => ["created_at","updated_at","public","currently_held_by_organization","created_by_user_id","owner_ids","min_age","max_age"]
		}
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
	## TAGS.
	##
	##
	#########################################################
	attribute :tags, Array[Tag], mapping: {type: 'nested', properties: Tag.index_properties}


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

	#attribute :inference, String, mapping: {type: 'text'}

	#validates_presence_of :inference, :if => Proc.new{|c| c.is_abnormal_range? }

	## @set_from : Diagnostics::Test#assign_Range
	## in that function, the range which suits the value and 
	## age and sex, is first picked, as the "picked" range
	## that may be abnormal or normal.
	## in case an abnormal range is picked, we also need to pick one range
	## as the normal range. This is marked as "normal_picked", this
	## is required to show as the normal biological reference range.
	attribute :normal_picked, Integer, mapping: {type: 'integer'}, default: -1

	## you cannot directly add the tag
	## you can however add them and edit them later
	## so that is the flow.
	attribute :template_tag_ids, Array, mapping: {type: 'keyword'}
		
	#######################################################
	##
	##
	## MIN MAX OVERLAP
	##
	##
	#########################################################
	validate :min_max_overlap

	def min_val_overlap(min_val,h)
		h.keys.each do |min_v|
			max_v = h[min_v]
			if (min_val >= min_v)
				if(min_val < max_v)
					self.errors.add(:tags,I18n.t("min_max_overlap_error"))
				end
			end
		end
	end

	def max_val_overlap(max_val,h)
		h.keys.each do |min_v|
			max_v = h[min_v]
			if (max_val <= max_v)
				if(max_val > min_v)
					self.errors.add(:tags,I18n.t("min_max_overlap_error"))
				end
			end
		end
	end

	def min_max_overlap

		min_max_values_hash = {}
		
		text_hash = {}

		self.tags.each do |tag|
			unless tag.min_range_val.blank?
				self.errors.add(:tags,I18n.t("min_max_overlap_error")) unless min_max_values_hash[tag.min_range_val].blank?
				
				if (tag.is_normal? || tag.is_abnormal?)
					min_val_overlap(tag.min_range_val,min_max_values_hash)
					max_val_overlap(tag.max_range_val,min_max_values_hash)
					min_max_values_hash[tag.min_range_val] = tag.max_range_val
				end
			else
				unless tag.text_range_val.blank?
					if text_hash[tag.text_range_val].blank?
						text_hash[tag.text_range_val] = tag.text_range_val
					else
						self.errors.add(:tags,I18n.t("text_overlap_error"))
					end
				end
			end
		end
	end

	##########################################################
	##
	##
	##
	##
	##
	##########################################################

	before_validation do |document|
		document.set_min_and_max_age
		document.update_tags
	end

	def remove_tags 
		#puts "came to remove tags.---------------->"
		
		self.tags.reject!{|c|
			
			#puts "tag range type is: #{c.range_type}"

			if c.is_history?
				#puts "it is a history tag"
				unless self.template_tag_ids.include? c.id.to_s
					#puts "the template tag ids don't include it"
					true
				else
					false
				end
			else
				false
			end

		}

	end

	def add_tags
		self.template_tag_ids.map{|t_id|
			if self.tags.select{|c|
				c.id.to_s == t_id
			}.size == 0
				tag = Tag.find(t_id)
				self.tags << tag
			end
		}
	end

	def update_tags
		#puts "came to update tags ------------------>"
		remove_tags
		add_tags
	end

	###########################################################
	##
	##
	## VALIDATIONS AND CALLBACKS.
	##
	##
	###########################################################
	def set_min_and_max_age

		self.min_age = (self.min_age_years*AGE_YEARS_MULTIPLIER) + (self.min_age_months*AGE_MONTHS_MULTIPLIER) + (self.min_age_days*AGE_DAYS_MULTIPLIER) + self.min_age_hours
		
		self.max_age = (self.max_age_years*AGE_YEARS_MULTIPLIER) + (self.max_age_months*AGE_MONTHS_MULTIPLIER) + (self.max_age_days*AGE_DAYS_MULTIPLIER) + self.max_age_hours
		
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
			:is_abnormal,
			:picked,
			:name, 
			:machine, 
			:kit, 
			:min_age,
			:max_age,
			:normal_picked,
			:active,
			:created_at,
	    	:updated_at,
	    	:public,
	    	:currently_held_by_organization,
	    	:created_by_user_id,
	    	:owner_ids,
	    	{
	    		:tags => Tag.permitted_params[1][:tag]
	    	},
	    	{
	    		:template_tag_ids => []
	    	}
		]
	end

	## so we have normal, 
	## abnormal may be multiple 
	## but cannot share the same min and max values
	## and the validation is carried out on range
	## we can have normal -> with tag -> 
	## the min and max cannot be the same for an abnormal value
	## if the option of the tag is the same
	## so there are fewer validations.
	## and you have to check if order breaks after this.
	## but today finish this with UI.
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
			},
			tags: {
				type: 'nested',
				properties: Tag.index_properties
			},
			template_tag_ids: {
				type: 'keyword'
			}
    	}

    	
	end

	def pick_range
		self.picked = 1
	end

	def pick_normal_range
		self.normal_picked = 1
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

=begin
	def is_normal_range?

	end

	def is_abnormal_range?
		self.is_abnormal == YES
	end
=end
	
	def has_normal_range?
		self.tags.select{|c|
			c.is_normal?
		}.size == 1
	end

	def is_male?
		self.sex == MALE
	end

	def is_female?
		self.sex == FEMALE
	end

end 
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
	attribute :min_age, Integer
		
	## This is also not permitted but internally calculate.
	attribute :max_age, Integer
	
	attribute :sex, String

	attribute :min_value, Float, :default => 0.0

	attribute :max_value, Float, :default => 0.0

	attribute :grade, String, mapping: {type: 'keyword'}

	attribute :count, String, mapping: {type: 'keyword'}

	attribute :name, String, mapping: {type: 'keyword', copy_to: 'search_all'}

	attribute :machine, String, mapping: {type: 'keyword'}

	attribute :kit, String, mapping: {type: 'keyword'}

	attribute :reference, String, mapping: {type: 'keyword'}


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
		self.min_age = (self.min_age_years*365*24) + (self.min_age_months*31*24) + (self.min_age_days*24) + self.min_age_hours

		self.max_age = (self.max_age_years*365*24) + (self.max_age_months*31*24) + (self.max_age_days*24) + self.max_age_hours
	end

=begin
	def self.permitted_params
		base = [:id,{:range => [:name, :test_id, :test_name, :min_age_years,:min_age_months,:min_age_weeks,:min_age_days, :max_age_years, :max_age_months,:max_age_days, :max_age_hours, :sex, :count, :grade, :machine, :kit, :reference]}]
		if defined? @permitted_params
			base[1][:range] << @permitted_params
			base[1][:range].flatten!
		end
		puts "the base becomes:"
		puts base.to_s
		base
	end
=end

	
	def self.permitted_params
		[
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
			:inference
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
			}
    	}
    	
	end

end 
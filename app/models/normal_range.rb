require 'elasticsearch/persistence/model'

class NormalRange
	
	include Elasticsearch::Persistence::Model

	include Concerns::NameIdConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern

	index_name "pathofast-normal-ranges"

	attribute :test_id, String

	attr_accessor :test_name
		
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

	attribute :count, String, mapping: {type: 'integer'}

	attribute :name, String, mapping: {type: 'keyword'}

	attribute :machine, String, mapping: {type: 'keyword'}

	attribute :kit, String, mapping: {type: 'keyword'}

	attribute :reference, String, mapping: {type: 'keyword'}

	after_find do |document|
		document.load_test_name
	end

	def test_id_exists
		begin
			Test.find(self.test_id)
		rescue
			self.errors.add(:test_id, "this test id does not exist")
		end
	end

	def load_test_name
		if self.test_name.blank?
			begin
				t = Test.find(self.test_id)
				self.test_name = t.name	
			rescue

			end
		end
	end

	## before doing any of this, we need to decide about our versioning strategy.
	## if it requires verification, then has to dump the attributes into a json string, and wait for verification.
	## then apply them if is accepted as verified.
	## how does this work exactly ?
	## if dr.sneha makes a change, someone else has to be there to verify it, anyone can create some change, but it will first have to be verified.
	## and what level user can verify it, will have to also be defined.
	## this doesnt affect authentication.
	## or authorization, just verification.
	## do i go for it or not ?
	## does it need to be on report also ?
	## how would it work with creation ?
	## doesn't hold for creation.
	## so suppose i made a new normal range, and added it to test.
	## then does that have to be verified ?
	## so that is an architecture issue from test side.
	## we can give a hook to search for normal ranges where test id is the same, but again we have the issue of id names.
	## different organizations, can have this issue also.
	## when you say name_id -> you can cause a lot of problems.
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

	end


	def self.permitted_params
		base = [:id,{:normal_range => [:name, :test_id, :test_name, :min_age_years,:min_age_months,:min_age_weeks,:min_age_days, :max_age_years, :max_age_months,:max_age_days, :max_age_hours, :sex, :count, :grade, :machine, :kit, :reference]}]
		if defined? @permitted_params
		
		else

		end
	end

end
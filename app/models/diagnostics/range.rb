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

	index_name "pathofast-ranges"

	## this range will load the test.
	## it doesn't need the test.
	## will search a test, which has this as the normal range.
	## and take that.
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

	attribute :count, String, mapping: {type: 'keyword'}

	attribute :name, String, mapping: {type: 'keyword', copy_to: 'search_all'}

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

	def load_test
		## what if it is added to more than one test
		## not allowed
		## that validation has to be added at the test level.
		## the problem is that if i edit my test, and i want to use the same normal range ?
		## then it has to copy all the normal ranges also?
		## this is all too complicated
		## make it nested
		## if they want to change anything, copy it new.
		## its totally pointless and too complicated otherwise.
		search_query = Test.search({
			query: {
				term: {
					ranges: self.id.to_s
				}
			}
		})

		search_query.response.hits.hits.each do |hit|

		end

	end

	

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

end 
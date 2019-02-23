require 'elasticsearch/persistence/model'

class NormalRange
	
	include Elasticsearch::Persistence::Model

	attribute :test_id, String

	attr_accessor :test_name
	
	attribute :min_age, Integer
	
	attribute :max_age, Integer
	
	attribute :sex, String

	attribute :min_value, Float

	attribute :max_value, Float

	validates_presence_of :test_id

	validate :test_id_exists

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

end
require 'elasticsearch/persistence/model'
class ItemRequirement 
	
	include Elasticsearch::Persistence::Model
	include Concerns::ImageLoadConcern

	index_name "pathofast-item-requirements"

	attribute :name, String

	attribute :item_type, String
	
	attribute :optional, String
	
	attribute :amount, Float
	
	attribute :priority, Integer

	attr_accessor :associated_reports

	## this may be a part of many reports.
	## but if report id is set on it, then it is to be giving an option 
	## to remove that report.
	## so first let me add that to the options.
	## then i can finish it.
	attr_accessor :report_id

	
	def load_associated_reports
		puts "loaded associated reports"
		self.associated_reports = []
	end

end
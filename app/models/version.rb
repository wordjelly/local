require 'elasticsearch/persistence/model'

class Version

	include Elasticsearch::Persistence::Model

	attribute :attributes_string, String
	attribute :verified_by_user_ids, Array
	attribute :verified, String
	attribute :verification_time, Date
	attribute :creation_time, Date
	attribute :control_doc_number, String

	attr_accessor :verified_by_users, Array

	after_find do |document|
		document.verified_by_users ||= []
		document.verified_by_user_ids.each do |uid|
			document.verified_by_users << User.find(uid)
		end
	end	

	## @return[String] a control doc_number
	## composed of current_year/current_epoch.to_s
	## eg : 2015/1551093091092
	## @called_from : base_controller_concner#update,create where version is being created.
	def assign_version_doc_number
		self.control_doc_number = Time.now.strftime("%Y") + "/" + Time.now.to_i.to_s
		self.control_doc_number
	end	

	
end
require 'elasticsearch/persistence/model'

class Version

	include Elasticsearch::Persistence::Model

	attribute :attributes_string, String
	attribute :verified_by_user_ids, Array
	attribute :verified, String
	attribute :verification_time, Date
	attribute :creation_time, Date

	attr_accessor :verified_by_users, Array

	after_find do |document|
		document.verified_by_users ||= []
		document.verified_by_user_ids.each do |uid|
			document.verified_by_users << User.find(uid)
		end
	end

end
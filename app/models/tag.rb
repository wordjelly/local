require 'elasticsearch/persistence/model'
class Tag

	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::CallbacksConcern

	index_name "pathofast-tags"

	attribute :name, String, mapping: {type: 'keyword', copy_to: "search_all"}
	validates_presence_of :name

	EMPLOYEE_TAG = "employee"
	COLLECTION_TAG = "collection"
	HISTORY_TAG = "history"
	## used to give the patient information about his test
	INFORMATION_TAG = "information"
	TAG_TYPES = [EMPLOYEE_TAG,COLLECTION_TAG,HISTORY_TAG]
	YES = 1
	NO = -1

	attribute :tag_type, String
	validates_presence_of :tag_type

	## what about order accessibility.
	## so how would this work exactly ?
	## we load it from remote
	## or copy paste ?
	## so we load template internally,
	## just like reports.
	## okay so that is doable.
	## and the validation.
	## so lets put that in the order validations.
	## suppose you added a test
	## if you want to add a value to that test
	## then the option has to be selected , but when.
	## before adding a value, there the validation error 
	## will be given.
	## We put that in order.
	## these history options are there.
	## but now which tag do you want to add
	## and how to accumulate them ?
	## as history tags ?
	## we put an array in the reports.
	## give autocomplete on the tag
	## should it be global ?
	attribute :history_options, Array, mapping: {type: 'keyword', copy_to: "search_all"}

	attribute :selected_option, String, mapping: {type: 'keyword'}

	attribute :selected_option_must_match_history_options, Integer, mapping: {type: 'integer'}, default: YES

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
	end

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
		
	end

	## here it is called a tag.
	## there you are calling it a history.

	def self.permitted_params
		[:id , {:tag => [:name, :tag_type, {:history_options => []}]}]
	end	


	######################################################3
	##
	##
	## HISTORY HELPERS
	##
	##
	######################################################
	def is_history_tag?
		self.tag_type == HISTORY_TAG
	end

	## @Called_from : test#history_provided?
	def history_provided?
		return true unless is_history_tag?
		!self.selected_option.blank?
	end


end
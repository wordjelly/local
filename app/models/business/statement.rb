require 'elasticsearch/persistence/model'

class Business::Statement

	include Elasticsearch::Persistence::Model
	include ActiveModel::Serialization
	include ActiveModel::Validations
  	include ActiveModel::Validations::Callbacks
  	include Concerns::OwnersConcern
	include Concerns::AllFieldsConcern
	include Concerns::NameIdConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::FormConcern
	include Concerns::CallbacksConcern


	attribute :payable_from_organization_ids, Array[Business::Receipt], mapping: {type: 'nested', properties: Business::Receipt.index_properties}
	attribute :payable_from_patient_ids, Array[Business::Receipt], mapping: {type: 'nested', properties: Business::Receipt.index_properties}
	attribute :payable_to_organization_ids, Array[Business::Receipt], mapping: {type: 'nested', properties: Business::Receipt.index_properties}
	
	attribute :payable_from_organization_id, String, mapping: {type: 'keyword'}
	attribute :payable_from_organization_id_after, String, mapping: {type: 'keyword'}
	
	attribute :payable_from_patient_id, String, mapping: {type: 'keyword'}
	attribute :payable_from_patient_id_after, String, mapping: {type: 'keyword'}
	
	attribute :payable_to_organization_id, String, mapping: {type: 'keyword'}
	attribute :payable_to_organization_id_after, String, mapping: {type: 'keyword'}

	attribute :all_receipts, Array[Business::Receipt], mapping: {type: 'nested', properties: Business::Receipt.index_properties}
	attribute :from,  Date, mapping: {type: 'date', format: 'yyyy-MM-dd'}, default: (Time.now - 30.days)
	attribute :to,  Date, mapping: {type: 'date', format: 'yyyy-MM-dd'}, default: Time.now
	attribute :search_after, Array, mapping: {type: 'keyword'}

	## used in the UI, to hide and show certain elements.
	attribute :show_bills_my_organization_has_to_pay, Integer, mapping: {type: 'integer'}
	attribute :show_bills_others_have_to_pay_my_organization, Integer, mapping: {type: 'integer'}
		

	attribute :balance, Float, mapping: {type: 'float'}
	## here we give an option -> top up balance
	## takes to order page ->
	## who is the patient ?
	## a dummy patient also has to be created.
	## this patient is called the user's patient.
	## so after creating the user/organization
	## a dummy patient has to be created also.
	## called the organization_representative patient.
	## so after create the organization -> we fire that/
	

	## @param[Hash] attribute_to_scroll : can be either :search_after, :payable_to_organization_id_after, :payable_from_patient_id_after, :payable_from_organization_id_after
	## @return[Hash] the hash for the link_to helper
	## @called_from : self#display_customizations
	def scroll_hash(attribute_to_scroll)
		{:id => self.id.to_s, :statement => {:from => self.from, :to => self.to, :payable_to_organization_id => self.payable_to_organization_id, :payable_from_organization_id => self.payable_from_organization_id, :payable_from_patient_id => self.payable_from_patient_id}.merge(attribute_to_scroll.to_s.to_sym => self.send(attribute_to_scroll.to_s))}
	end	

	## @used_in : /views/shared/display_nested.html.erb
	def display_customizations(root=nil)
		customizations = {}
		customizations["payable_to_organization_id_after"] = link_to('Show more organizations to whom bills are pending', Rails.application.routes.url_helpers.business_statement_path(scroll_hash("payable_to_organization_id_after")), :method => :put)
		customizations["payable_from_organization_id_after"] = link_to('Show more organizations who have to pay bills', Rails.application.routes.url_helpers.business_statement_path(scroll_hash("payable_from_organization_id_after")), :method => :put)
		customizations["payable_from_patient_id_after"] = link_to('Show more patients who have to pay bills', Rails.application.routes.url_helpers.business_statement_path(scroll_hash("payable_from_patient_id_after")), :method => :put)
		customizations["search_after"] = link_to('Show more receipts', Rails.application.routes.url_helpers.business_statement_path(scroll_hash("search_after")), :method => :put)
		customizations
	end

	## we add a hidden field called name.
	def customizations(root)

		customizations = {}

		## so on clicking that accessor.
		## it should add our organization id internally or here ?
		## i can do that internally.
		## easer to deal with model side.

		customizations["show_bills_my_organization_has_to_pay"] =
		'<p><label><input type="checkbox" id="statement_show_bills_my_organization_has_to_pay" name="statement[show_bills_my_organization_has_to_pay]" /><span>show bills my organization has to pay</span></label></p>'

		customizations["show_bills_others_have_to_pay_my_organization"] =
		'<p><label><input type="checkbox" id="statement_show_bills_others_have_to_pay_my_organization" name="statement[show_bills_others_have_to_pay_my_organization]" /><span>Show bills others have to pay my organization</span></label></p>'

		customizations["payable_from_organization_id"] = "<input type='text' id='statement_payable_from_organization_id' name='statement[payable_from_organization_id]' data-autocomplete-type='organizations' data-use-id='yes'></input><label for='statement[payable_from_organization_id]'>payable from organization</label>"

		customizations["payable_to_organization_id"] = "<input type='text' id='statement_payable_to_organization_id' name='statement[payable_to_organization_id]' data-autocomplete-type='organizations' data-use-id='yes'></input><label for='statement[payable_to_organization_id]'>payable to organization</label>"
		
		customizations["payable_from_patient_id"] = "<input type='text' id='statement_payable_from_patient_id' name='statement[payable_from_patient_id]' data-autocomplete-type='patients' data-use-id='yes'></input><label for='statement[payable_from_patient_id]'>Payable from Patient</label>"
		
		customizations

	end

	def fields_not_to_show_in_form_hash(root="*")
		{
			"*" => ["outsourced_report_statuses","merged_statuses","search_options","procedure_versions_hash","latest_version","patient_id","template_report_ids","name","verified_by_user_ids","rejected_by_user_ids","payable_from_organization_id_after","payable_from_patient_id_after","payable_to_organization_id_after","versions","owner_ids","active","public","created_at","updated_at","created_by_user_id","currently_held_by_organization","search_after"]
		}
	end

	

	COMPOSITE_AGGREGATION_SIZE = 10
	SEARCH_RESULTS_SIZE = 10

	def self.permitted_params
		[:id, {:statement => [:show_bills_my_organization_has_to_pay,:show_bills_others_have_to_pay_my_organization,:id,:payable_from_organization_id,:payable_to_organization_id,:payable_from_patient_id,:payable_from_organization_id_after,:payable_to_organization_id_after,:payable_from_patient_id_after,{:all_receipts => []},{:payable_to_organization_ids => []},{:payable_from_organization_ids => []},{:payable_from_patient_ids => []},:from,:to,{:search_after => []}]}]
		
	end

	def add_to_aggregation(aggregation,after_aggregations,val)
		aggregation[(val + "s").to_sym] = {
			composite: {
				size: COMPOSITE_AGGREGATION_SIZE,
				sources: [
					{
			            val.to_sym => {
			              terms: {
			                field: val.to_s
			              }
			            }
			        }
				]
			},
			aggs: {
				pending_amount: {
					sum: {
						field: "pending"
					}
				}
			}
		}

		## now to make a payment.
		## who recieved the payment.
		## that is the main thing.
		## suppose i am a patient.
		## now first create the patient's organizaiton.
		## then he chooses the patient.
		## so how to make a payment.
		## who can make the payment ?
		## basically can payment be added ?
		## receipts are created automatically.
		## but payments can only be added into them.
		## and the payumoney workflow.
		## receive it
		## staff is receiving a payment from a patient.
		## patient makes a booking online
		## and pays.

		unless after_aggregations[(val + "s").to_sym].blank?
			aggregation[(val + "s").to_sym][:composite][:after] = after_aggregations[(val + "s").to_sym]
		end
	end

	def add_to_query(query,val)
		query[:bool][:must] << {
			terms: {
				val.to_sym => [self.send(val.to_sym)]
			}
		}
	end

	## @param[Hash] after_aggregations : the after_aggregations hash.
	## structure : [key] attribute_name, [value] hash {key -> value}
	## eg: 
	##  
	## @return[nil] : simply appends to the existing aggregations, will populate the all_receipts attribute only if the after_aggregations are blank.
	def make_search_request(after_aggregations={})
		
		after_aggregations.deep_symbolize_keys!

		self.to ||= Time.now
		
		self.from ||= self.to - 30.days
		
		query = 
		{
			bool: {
				must: [
					{
						range: {
							updated_at: {
								gte: self.from,
								lte: self.to + 1.day
							}
						}
					}
				]
			}
		}


		aggregation = {
				
		}


		["payable_from_organization_id","payable_to_organization_id","payable_from_patient_id"].each do |val|
			
				unless self.send(val.to_sym).blank?
					add_to_query(query,val)
				else
					add_to_aggregation(aggregation,after_aggregations,val)
				end
			
		end

		body = {
			size: SEARCH_RESULTS_SIZE,
			sort: [
				{updated_at: "desc"},
				{_id: "desc"}
			],
			query: query
		}

		body[:aggs] = aggregation unless aggregation.blank?

		body[:search_after] = self.search_after unless self.search_after.blank?
		
		puts JSON.pretty_generate(body)

		Business::Receipt.search(body)

	end	

	## so we have only two options
	## bills I have to pay
	## bills others have to pay me.
	## what about a special cas
	## if i click bills payable to me.
	## then the javascript has to change the value of the hidden field.
	## if i click another checkbox then it has to change that.
	## 

	## so we don't want to add any new plain array elements.
	def add_new_plain_array_element(root,collection_name,scripts,readonly)
		''
=begin
		script_id = BSON::ObjectId.new.to_s
		script_open = '<script id="' + script_id + '" type="text/template" class="template"><div style="padding-left: 1rem;">'
		scripts[script_id] = script_open
		scripts[script_id] +=  '<input type="text" name="' + root + '[' + collection_name + '][]" /> <label for="' + root + '[' + collection_name + '][]">' + collection_name.singularize + '</label></div></script>'
		element = "<a class='waves-effect waves-light btn-small add_nested_element' data-id='#{script_id}'><i class='material-icons left' >cloud</i>Add #{collection_name.singularize}</a>"
		element
=end
	end

	def build_after_aggregations
		after_aggregations = {}

		unless self.payable_to_organization_id_after.blank?
			after_aggregations[:payable_to_organization_ids] = {
				payable_to_organization_id: self.payable_to_organization_id_after
			}
		end

		unless self.payable_from_organization_id_after.blank?
			after_aggregations[:payable_from_organization_ids] = {
				payable_from_organization_id: self.payable_from_organization_id_after
			}
		end

		unless self.payable_from_patient_id_after.blank?
			after_aggregations[:payable_from_patient_ids] = {
				payable_from_patient_id: self.payable_from_patient_id_after
			}
		end

		after_aggregations
	end

	## sorts out the checkboxes 
	def process_checkboxes(current_user)
		self.payable_from_organization_id = current_user.organization.id.to_s if self.show_bills_my_organization_has_to_pay

		self.payable_to_organization_id = current_user.organization.id.to_s if self.show_bills_others_have_to_pay_my_organization
	end

	def generate_statement(current_user)
		
		self.id = BSON::ObjectId.new.to_s

		process_checkboxes(current_user)

		after_aggregations = build_after_aggregations
		
		search_request = make_search_request(after_aggregations)
		
		search_request.response.hits.hits.each do |hit|
			r = Business::Receipt.new(hit._source)
			r.id = hit._id
			self.all_receipts << r
		end

		unless search_request.response.aggregations.blank?
			search_request.response.aggregations.keys.each_with_index {|k,key| 
				unless search_request.response.aggregations[k]["buckets"].blank?
					if self.respond_to? k.to_s.to_sym
						if !search_request.response.aggregations[k]["after_key"].blank?
							self.send(k[0..-2] + "_after=",search_request.response.aggregations[k]["after_key"])
						else
							self.send(k[0..-2] + "_after=",search_request.response.aggregations[k]["buckets"][-1]["key"][k[0..-2]])
						end
						search_request.response.aggregations[k]["buckets"].each do |receipt_bucket|
							r = Business::Receipt.new
							r.send((k[0..-2]).to_s + "=",receipt_bucket["key"][k[0..-2]]) 
							r.pending = receipt_bucket["pending_amount"]["value"]
							self.send(k.to_sym) << r 
						end
					end
				end
			}
		end
		self.search_after = search_request.response.hits.hits[-1]["sort"] unless search_request.response.hits.hits.blank?
	end

	

end

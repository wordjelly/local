require 'elasticsearch/persistence/model'

class Business::Receipt

	include Elasticsearch::Persistence::Model
	include ActiveModel::Serialization
	include ActiveModel::Validations
  	include ActiveModel::Validations::Callbacks
  	include Concerns::OwnersConcern
	include Concerns::AllFieldsConcern
	include Concerns::NameIdConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::VersionedConcern
	include Concerns::FormConcern
	include Concerns::PdfConcern
	include Concerns::CallbacksConcern



	attribute :name, String, mapping: {type: 'keyword'}, default: BSON::ObjectId.new.to_s

	attribute :payable_to_organization_id, String, mapping: {type: 'keyword'}	
	
	attribute :payable_from_organization_id, String, mapping: {type: 'keyword'}

	attribute :payable_from_patient_id, String, mapping: {type: 'keyword'}

	attribute :payments, Array[Business::Payment]

	attribute :total, Float, mapping: {type: 'float'}, default: 0
		
	attribute :paid, Float, mapping: {type: 'float'}, default: 0

	attribute :pending, Float, mapping: {type: 'float'}, default: 0
		


	LOCKED = "locked"

	UNLOCKED = "unlocked"

	######################################################
	##
	##
	## ATTRIBUTES USED IN THE PDF'S 
	## basically we load the organizations that are 
	## referenced in the receipts.
	##
	##
	##
	######################################################
	attr_accessor :payable_from_organization
	attr_accessor :payable_from_patient
	attr_accessor :payable_to_organization
	#####################################################
	##
	## for standalone existing of receipt objects.
	## 
	##
	##
	#####################################################
	### we should be able to take any kind of doctor's report also.

	index_name "pathofast-business-receipts"
	document_type "business/receipt"

	settings index: { 
	    number_of_shards: 1, 
	    number_of_replicas: 0,
	    analysis: {
		      	filter: {
			      	nGram_filter:  {
		                type: "nGram",
		                min_gram: 2,
		                max_gram: 20,
		               	token_chars: [
		                   "letter",
		                   "digit",
		                   "punctuation",
		                   "symbol"
		                ]
			        }
		      	},
	            analyzer:  {
	                nGram_analyzer:  {
	                    type: "custom",
	                    tokenizer:  "whitespace",
	                    filter: [
	                        "lowercase",
	                        "asciifolding",
	                        "nGram_filter"
	                    ]
	                },
	                whitespace_analyzer: {
	                    type: "custom",
	                    tokenizer: "whitespace",
	                    filter: [
	                        "lowercase",
	                        "asciifolding"
	                    ]
	                }
	            }
	    	}
	  	} do

	    mapping do
		    indexes :name, type: 'keyword', fields: {
		      	:raw => {
		      		:type => "text",
		      		:analyzer => "nGram_analyzer",
		      		:search_analyzer => "whitespace_analyzer"
		      	}
		    },
	   	 	copy_to: "search_all"
		    indexes :payable_to_organization_id, type: 'keyword'
		    indexes :payable_from_organization_id, type: 'keyword'
		    indexes :payable_from_patient_id, type: 'keyword'
		    indexes :payments, type: 'nested', properties: Business::Payment.index_properties
		    indexes :total, type: 'float'
		    indexes :paid, type: 'float'
		    indexes :pending, type: 'float'
		end
	end

	#####################################################
	##
	##
	## VALIDATIONS
	##
	##
	######################################################
	validate :mode_of_newly_added_payment

	validate :type_of_newly_added_payment

	def mode_of_newly_added_payment
		self.payments.select{|c|
			((c.new_record?) && (c.has_created_by_user_id?))
		}.each do |payment|
			if current_user_from_payable_from_org?
				self.errors.add(:payments, "payment mode: #{payment.payment_mode} is not allowed.") if (payment.is_physical?)
			end
		end
	end

	## so we did mode and type of newly added payment.
	## what about balance payment.
	## so if you add a payment is it newly added?
	## when it comes from remote, what is it?
	## it is loaded -> so falsified.
	## 
	def type_of_newly_added_payment
		self.payments.select{|c|
			((c.new_record?) && (c.has_created_by_user_id?))
		}.each do |payment|
			if payment.is_a_bill?
				self.errors.add(:payments,"you cannot add a bill directly")
			elsif payment.is_a_discount?

			end
		end
	end

	## is the patient organization getting created while
	## creating a patient
	## or the users organization 
	## if the user is a patient.
	## gotta sort this out.
	

	def self.permitted_params
		[:id,:payable_to_organization_id,:payable_from_organization_id,:payable_from_patient_id,{ :payments => Business::Payment.permitted_params }, :created_by_user_id, :currently_held_by_organization]
	end	

	def self.index_properties
		{
			payable_to_organization_id: {
				type: 'keyword'
			},
			payable_from_organization_id: {
				type: 'keyword'
			},
			payable_from_patient_id: {
				type: 'keyword'
			},
			payments: {
				type: 'nested',
				properties: Business::Payment.index_properties
			},
			total: {
				type: 'float'
			},
			paid: {
				type: 'float'
			},
			pending: {
				type: 'float'
			}
		}
	end

	## @called_from : order_concern#update_receipt_totals
	## if the payment has been marked as newly_created in config/initializers#hash, then we set the created_by_user, and created_by_user_id, as the current user from the order.
	def set_payment_created_by(current_user)
		self.payments.each do |payment|
			if !payment.is_a_bill?
				payment.created_by_user = current_user
				payment.created_by_user_id = current_user.id.to_s
			end
		end
	end

	## then we write other validations on the payment itself.
	## to check that nothing has changed.
	## except approved/declined for online payments.

	def has_bill?(payment)
		self.payments.select{|c|
			(c.for_report_id == payment.for_report_id) && (!c.is_cancelled?)
		}.size == 1
	end

	def add_bill(payment)
		#puts "Came to add bill for report: #{payment.for_report_name}"
		unless has_bill?(payment)
			self.payments << payment
			self.force_pdf_generation = true
		else
			## i think after hash assign.
			#puts "already has bill for : #{payment.for_report_name}, and its newly added is: #{payment.newly_added}"
		end
	end

	def add_payment(payment)
		self.payments << payment
		self.force_pdf_generation = true
	end

	## @called_from : order_concern#validation
	def parameter_other_than_payments_changed?
		#puts "the changed attributes are:"
		#puts self.changed_attributes.to_s
		return false if self.changed_attributes.blank?
		if self.changed_attributes.size > 1
			return true
		elsif self.changed_attributes.size == 1
			if self.changed_attributes[0].to_s != "payments"
				return true
			end 
		end
		return false
	end
	
	## called_from : 
	## a. order_concern#on_remove_report.
	## if a report is removed, then bills levied for it are 
	## also deducted.
	def cancel_payments(args={})
		return if args.blank?
		if args[:report]
			self.payments.each do |payment|
				if payment.is_a_bill?
					if payment.for_report_id == args[:report].id.to_s
						payment.cancel
						self.force_pdf_generation = true
					end
				end
			end
		end
	end

	def requires_total_update?
		if self.changed_array_attribute_sizes.include? :payments
			return true
		else
			payment_status_changed = false
			self.payments.each do |payment|
				if payment.changed_attributes.include? :status
					payment_status_changed = true	
				end
			end
			payment_status_changed
		end
	end

	## @called_from : self#add_bill, self#add_payment, self#cancel_payments
	def update_total
		return true unless requires_total_update?
		self.total = 0
		self.pending = 0
		self.paid = 0
		self.payments.each do |payment|
			if payment.is_approved?
				if payment.is_a_bill?
					self.total += payment.amount
				else
					self.paid += payment.amount
				end
			else
				if payment.is_from_balance?
					## so i want to check if has_balance works
					## or not.
					## so i need to setup the controller specs.
					## nothing will move forwards otherwise.
					## then comes the dropdowns.
					## we change everything including the way
					## it is displayed.
					## i could sort it out.
					self.paid += payment.amount if has_balance?(payment.amount)
				end
			end
		end
		transaction_successfull = false
		self.pending = (self.total - self.paid)
		$redis.watch(get_race_condition_key_name)
			unless locked?
				result = $redis.multi do |multi|
					multi.set(get_race_condition_key_name,LOCKED)
					begin
						## you call validate
						if self.save(validate: false)
							## even then the accessors will be washed off
							## 
						else
							#self.errors.add(:payments, "failed to commit receipt")
							transaction_successfull = false
						end
					rescue
						transaction_successfull = false
						#self.errors.add(:payments, "failed to commit receipt")
					end
					multi.set(get_race_condition_key_name,UNLOCKED)
				end
				#puts "multi result is:"
				## so if this is the result.
				#puts result.to_s
				if result.blank?
					transaction_successfull = false
					#self.errors.add(:payments, "another payment is being made from your organization, please wait for it to complete, and try again later")
				end
			else
				transaction_successfull = false
				#self.errors.add(:payments, "another payment is being made from your organization, please wait for it to complete, and try again later")
			end
		$redis.unwatch
		transaction_successfull
	end
	
	## so do we do UI or what ?
	## the dropdown and all that
	## and some design shennanigans
	## or i can do both.
	## then there will be the run.
	## and what about the payment -> with payumoney and the patient.
	## payment verification and approval.
	## it is all pending.
	## check transactions
	## check top up?
	## and who can approve and create payments.
	## then how the patient will make a payment.
	## and then the payumoney intergration from the older code.
	## so let me start with tests for transactions

	##############################################################
	##
	##
	## TO CALCULATE BILL RECEIPTS
	##
	##
	##############################################################
	def locked?
		#puts "Came to check locked."
		if $redis.get(get_race_condition_key_name).blank?
			#puts "the key is blank"
			false
		else
		   #puts "key is not blank"
		   #puts "key is: #{$redis.get(get_race_condition_key_name)}"
		   $redis.get(get_race_condition_key_name) == LOCKED
		end
	end

	## @called_from : self#update_total before the save command.
	def get_race_condition_key_name
		self.payable_from_organization_id.to_s + "-balance-lock"
	end

	def has_balance?(amount)
		#statement = payable_from_organization.get_organization_balance_statement(nil)
		#((statement.payable_from_organization_ids.first.pending < 0) && (statement.payable_from_organization_ids.first.pending.abs > amount))
		return true
	end
	##############################################################
	##
	##
	## PDF GENERATION
	##
	##
	##############################################################
	def get_pdf_file_name
		
		time_stamp = Time.now.strftime("%b %-d_%Y")

		if !self.payable_from_organization_id.blank?
			return self.payable_to_organization_id + "_" + self.payable_from_organization_id + "_" + time_stamp 
		elsif !self.payable_from_patient_id.blank?
			return self.payable_to_organization_id + "_" + self.payable_from_patient_id + "_" + time_stamp
		end

	end

	


	## We never call this method directly
	## We call process_pdf.
	def generate_pdf
		
		#puts "came to generate pdf in receipt------------->"
		self.payable_from_organization = Organization.find(self.payable_from_organization_id) unless self.payable_from_organization_id.blank?

		self.payable_from_patient = Patient.find(self.payable_from_patient_id) unless self.payable_from_patient_id.blank?

		self.payable_to_organization = Organization.find(self.payable_to_organization_id) unless self.payable_to_organization_id.blank?
 	
		file_name = get_pdf_file_name

		ac = ActionController::Base.new

		pdf = ac.render_to_string pdf: file_name,
	            template: "#{ Auth::OmniAuth::Path.pathify(self.class.name).pluralize}/pdf/show.pdf.erb",
	            locals: {:receipt => self},
	            layout: "pdf/application.html.erb",
            	quiet: true,
	            header: {
	            	html: {
	            		template:'/layouts/pdf/receipt_header.pdf.erb',
	            		layout: "pdf/application.html.erb",
	            		locals:  {:receipt => self}
	            	}
	            },
	            footer: {
	           		html: {   
	           			template:'/layouts/pdf/receipt_footer.pdf.erb',
	           			layout: "pdf/application.html.erb",
	            		locals: {:receipt => self}
	                }
	            }       

        save_path = Rails.root.join('public',"#{file_name}.pdf")
		File.open(save_path, 'wb') do |file|
		  file << pdf
		  self.pdf_urls = [save_path]
		end
		self.skip_pdf_generation = true
	end

	## so let us make the templates
	## for prepaid and postpaid orders
	## and policy settings.
	#################################################################
	##
	##
	## OVERRIDES FROM FORM CONCERN -> to show nested objects.
	##
	##
	#################################################################
	def summary_row(args={})
		'
			<tr>
				<td>' + self.created_at.strftime("%b %-d_%Y") + '</td>
				<td>' + (self.payable_to_organization_id || "-") + '</td>
				<td>' + (self.payable_from_organization_id || "-") + '</td>
				<td>' + (self.payable_from_patient_id || "-") + '</td>
				<td>' + self.total.to_s + '</td>
				<td>' + self.paid.to_s + '</td>
				<td>' + self.pending.to_s + '</td>
				<td><div class="edit_nested_object"  data-id=' + self.unique_id_for_form_divs + '>Edit</div></td>
			</tr>
		'
	end

	## should return the table, and th part.
	## will return some headers.
	def summary_table_headers(args={})
		'''
			<thead>
	          <tr>
	              <th>Created At</th>
	              <th>Payable To Organization Id</th>
	              <th>Payable From Organization Id</th>
	              <th>Payable From Patient Id</th>
	              <th>Total</th>
	              <th>Paid</th>
	              <th>Pending</th>
	              <th>Options</th>
	          </tr>
	        </thead>
		'''
	end

	## if the root is an order, we don't want the add new button.
	def add_new_object(root,collection_name,scripts,readonly)
			
		if root =~ /order|statement/
			''
		else
			
			script_id = BSON::ObjectId.new.to_s

			script_open = '<script id="' + script_id + '" type="text/template" class="template"><div style="padding-left: 1rem;">'
			
			scripts[script_id] = script_open

			scripts[script_id] +=  new_build_form(root + "[" + collection_name + "][]",readonly,"",scripts) + '</div></script>'
		
			element = "<a class='waves-effect waves-light btn-small add_nested_element' data-id='#{script_id}'><i class='material-icons left' >cloud</i>Add #{collection_name.singularize}</a>"

			element

		end

	end

	def fields_not_to_show_in_form_hash(root="*")
		{
			"*" => ["versions","owner_ids","active","public","created_at","updated_at","created_by_user_id","currently_held_by_organization","verified_by_user_ids","rejected_by_user_ids","name","payable_from_organization_id","payable_from_patient_id","payable_to_organization_id"]
		}
	end

	######################################################
	##
	##
	## OVERRIDEN FROM OWNERS CONCERN.
	##
	##
	######################################################
	def add_owner_ids
		self.owner_ids << self.payable_from_organization_id 
		self.owner_ids << self.payable_to_organization_id
		self.owner_ids << self.payable_from_patient_id
		self.owner_ids.compact!
		self.owner_ids.uniq!
	end


	######################################################
	##
	##
	## HELPERS FOR QUERIES FROM THE RECEIPTS_CONTROLLER.RB
	##
	##
	######################################################
	## @return[Boolean] true/false : true if we are only going to generate a summary of the data.
	## basically if any of the two from the array below are provided, we will simply show all the receipts that lie between from - to.
	## if only any one of the three are provided we generate a statement of summary like (either from/to that organzation id) => total pending, in the period specified, stratified by month. 
	def only_show_summary?
		count = 0	
		["payable_from_organization_id","payable_to_organization_id","payable_from_patient_id"].each do |k|
			count+=1 unless self.send(k.to_sym).blank?
		end
		count <= 1
	end	

	## @used_in : order_concern#generate_Receipt_pdfs
	## used to check if any of the payments statuses were changed
	## to regenerate the receipts.
	def any_payment_status_changed?
		#puts "came to check if any payment status changed."
		selected_payments = self.payments.select{|c|
			#puts "checking payment, changed attributes"
			#puts c.changed_attributes.to_s
			c.changed_attributes.include? "status"
		}
		#puts "selected payments are:"
		#puts selected_payments.to_s
		selected_payments.size > 0
	end

	############################################################
	###
	###
	### helpers used inside validations inside self.
	###
	############################################################
	def current_user_from_payable_to_org?
		self.current_user.organization.id.to_s == self.payable_to_organization_id
	end

	def current_user_from_payable_from_org?
		self.current_user.organization.id.to_s == self.payable_from_organization_id
	end

	

end
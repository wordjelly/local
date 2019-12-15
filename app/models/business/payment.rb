require 'elasticsearch/persistence/model'

class Business::Payment

	YES = 1
	NO = 0
	CASH = "Cash"
	CARD = "Card"
	CHEQUE = "Cheque"
	ONLINE = "Online"
	BALANCE = "From Balance"
	DISCOUNT = "Discount"
	BILL = "Bill"
	PAYMENT = "Payment"
	APPROVED = YES
	PENDING = -1
	CANCELLED = NO
	PAYMENT_MODES = [CASH,CARD,CHEQUE,ONLINE,BALANCE]
	PAYMENT_TYPES = [DISCOUNT,BILL,PAYMENT]
	STATUSES = [APPROVED,PENDING,CANCELLED]
	STATUSES_OPTIONS = [["Approved",APPROVED],["pending",PENDING],["cancelled",CANCELLED]]
	DEFAULT_PAYMENT_MODE = CASH

	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::NameIdConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::VersionedConcern
	include Concerns::FormConcern
	include Concerns::CallbacksConcern
	include Concerns::PayUMoneyConcern
		
	

	attribute :name, String, mapping: {type: 'keyword'}

	attribute :amount, Float, mapping: {type: 'float'}
	attribute :for_report_id, String, mapping: {type: 'keyword'}
	attribute :for_report_name, String, mapping: {type: 'keyword'}
	attribute :payment_type, String, mapping: {type: 'keyword'}
	attribute :payment_mode, String, mapping: {type: 'keyword'}
	attribute :status, Integer, mapping: {type: 'integer'}

	##############################################################
	##
	## PAYUMONEY ATTRIBUTES
	##
	##############################################################
	## calc_hash === outgoing hash.
	## -> status saved.
	## if the payment status has changed -> and it is anything other than accepted , in case of an online payment, then 
	###################################################### ATTRIBUTES EXPECTED FROM PAYUMONEY IN THE CALLBACK
	###################################################

	attribute :incoming_hash, String, mapping: {type: 'keyword'}
	
	## received from payumoney in the callback.
	attribute :mihpayid, String, mapping: {type: 'keyword'}

	## incoming payment status.
	attribute :payumoney_payment_status, String, mapping: {type: 'keyword'}

	##################################################
	##
	## ATTRIBUTES SENT TO PAYUMONEY
	##
	##################################################
	## the hash sent by us to payumoney while doing the payment flow.
	attribute :outgoing_hash, String, mapping: {type: 'keyword'}

	
	## so this field, is going to come from that side
	## actually we don't care much.
	attribute :udf5, String, mapping: {type: 'keyword'}, default: "BOLT_KIT_ROR"

	##############################################################
	##
	##
	## missing method concern overrides
	##
	##
	#############################################################
	def new_record?
		self.newly_added
	end

	####################################################
	##
	##
	## before_save ?
	## would new record be set ?
	## i think so .
	## newly added is defined before that.
	## so if the hash is not there, then how to set the
	## hash.
	##
	##
	####################################################
		
	##############################################################
	##
	##
	## VALIDATIONS
	##
	##
	##############################################################
	validates_presence_of :payment_type
	validates_presence_of :payment_mode, :unless => Proc.new{|c| c.is_a_bill?}
	validate :status_changed_by_same_organization, :if => Proc.new{|c| c.new_record? == false }
	validate :no_parameter_other_than_status_changed, :if => Proc.new{|c| c.new_record? == false }
	validate :status_change_conditions

	## okay so let us say we are creating it the first time.
	## what would it be like
	## if it came from the controller
	## would be same -> false.
	## for an existing bill also it would have been false.
	## as after_find would have cascaded
	## in that case changed attributes would have applied.
	def status_changed?
		return false if self.changed_attributes.blank?
		self.changed_attributes.include? :status
	end

	def status_changed_by_same_organization
		if status_changed?
			self.errors.add(:status,"you cannot change the status of this payment") if (self.current_user.organization.id.to_s != self.currently_held_by_organization)
		end
	end

	def no_parameter_other_than_status_changed
		return if self.changed_attributes.blank?
		#return if self.payment_mode.blank?
		mode = self.payment_mode || DEFAULT_PAYMENT_MODE
		self.changed_attributes.each do |attr|
			
			unless payment_changeable_attributes[mode].include? attr.to_sym
				self.errors.add(:status,"you cannot change #{attr.to_s} for this mode of payment: #{self.payment_mode.to_s}")
			end
		end
	end

	## so first of all you cannot change the status directly, in case it is not a new record.
	def status_change_conditions
		#puts "payment mode is:"
		#puts self.payment_mode.to_s
		#puts "payment permitted status changes ---->"
		#puts payment_permitted_status_changes.to_s
		return if self.is_a_bill?
		return if self.payment_mode.blank?

		if self.new_record?
			
			self.errors.add(:status, "permitted status for this mode of payment is #{payment_permitted_status_changes[self.payment_mode][0]}") unless self.status == payment_permitted_status_changes[self.payment_mode][0]
		else
			#puts "its not a new record"
			if self.changed_attributes.include? "status"
				self.errors.add(:status, "this mode of payment can only have its status changed to -> #{payment_permitted_status_changes[self.payment_mode][1]}") unless self.status == payment_permitted_status_changes[self.payment_mode][1]
			end
		end
	end

	## @Return[Hash]
	## key -> payment_type
	## value -> [Array] list of parameters
	## @used_in : self#no_parameter_other_than_status_changed
	## basically only the attributes defined here are allowed to change.
	def payment_changeable_attributes
		{
			CASH => [:status],
			CARD => [:status],
			CHEQUE => [:status],
			ONLINE => [:status,:incoming_hash,:payumoney_payment_status],
			BALANCE => [:status]
		}
	end

	## defines how the status can be changed for each payment type.
	## so for example -> when a cash payment is CREATED, it has to have a status of approved.
	## and thereafter its status can only be changed to CANCELLED by means of an update.
	## so when the status changes , it checks the payment type, and sees if the status has changed to the last element in the array.
	## once its status has been updated to that, it cannot be changed again, or it will raise an error.
	## once something is approved it cannot be cancelled again.
	## you make another payment -> additional.
	## in case of "online", status is changed internally in the callback, so there is no way of changing this status for anyone, so both elements in the array are same i.e pending.
	def payment_permitted_status_changes
		{
			CASH => [APPROVED,CANCELLED],
			CARD => [APPROVED,CANCELLED],
			CHEQUE => [PENDING,APPROVED],
			ONLINE => [PENDING,PENDING],
			BALANCE => [APPROVED,CANCELLED]
		}
	end


	## @param[String] from_organization_id : the organization from which the bill is being given to the patient.
	## @param[Patient] patient : the patient.
	## @param[Diagnostics::Report] : the report for which the patient is being billed.
	## @return[Business::Payment]
	## @Called_from : order_concern#receipt_to_patient
	def self.bill_patient_for_report(from_organization_id,patient,report)
		new(amount: report.get_patient_rate, for_report_id: report.id.to_s, for_report_name: report.name, status: APPROVED, payment_type: BILL, newly_added: true)
	end

	## @param[Diagnostics::Report] : the report for which the patient is being billed.
	## @param[Business::Order] : the primary order.
	## @return[Business::Payment]
	## @called_from : order_concern#receipt_to_order_organization
	def self.bill_from_outsourced_organization_to_order_organization(report,order)
		new(amount: report.get_organization_rate(order.organization.id.to_s), for_report_id: report.id.to_s, for_report_name: report.name, status: APPROVED, payment_type: BILL, newly_added: true)
	end

	def self.permitted_params
		[:id,:amount,:for_report_id,:for_report_name,:payment_type,:payment_mode,:name,:status,:created_by_user_id,:currently_held_by_organization,:incoming_hash,:mihpayid,:payumoney_payment_status]
	end	

	def self.index_properties
		{
			amount: {
				type: 'float'
			},
			for_report_id: {
				type: 'keyword'
			},
			for_report_name: {
				type: 'keyword'
			},
			payment_type: {
				type: 'keyword'
			},
			payment_mode: {
				type: 'keyword'
			},
			outgoing_hash: {
				type: 'keyword'
			},
			incoming_hash: {
				type: 'keyword'
			},
			mihpayid: {
				type: 'keyword'
			},
			payumoney_payment_status: {
				type: 'keyword'
			},
			udf5: {
				type: 'keyword'
			}
		}
	end

	def summary_row(args={})
		'
			<tr>
				<td>' + self.created_at.strftime("%b %-d_%Y") + '</td>
				<td>' + self.amount.to_s + '</td>
				<td>' + (self.for_report_id || "-") + '</td>
				<td>' + (self.for_report_name || "-") + '</td>
				<td>' + (self.payment_type || "-") + '</td>
				<td>' + (self.payment_mode || "-") + '</td>
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
	              <th>Amount</th>
	              <th>For Report Id</th>
	              <th>For Report Name</th>
	              <th>Payment Type</th>
	              <th>Payment Mode</th>
	              <th>Options</th>
	          </tr>
	        </thead>
		'''
	end

	def fields_not_to_show_in_form_hash(root="*")
		## payment mode and payment type have to be customized
		## as drop downs.
		{
			"*" => ["versions","owner_ids","active","public","created_at","updated_at","created_by_user_id","currently_held_by_organization","verified_by_user_ids","rejected_by_user_ids","name","status","for_report_id","for_report_name"]
		}
	end

	def customizations(root)

		customizations = {}

		customizations["payment_mode"] = "<div class='input-field'>" + (select_tag(root + "[payment_mode]",options_for_select(PAYMENT_MODES),{:include_blank => true})) + "<label>Choose Payment Mode</label></div>"

		customizations["payment_type"] = "<div class='input-field'>" + (select_tag(root + "[payment_type]",options_for_select(PAYMENT_TYPES,(self.payment_type || BILL)))) + "<label>Choose Payment Type</label></div>"

		customizations["status"] = "<div class='input-field'>" + (select_tag(root + "[status]",options_for_select(STATUSES_OPTIONS,(self.status || PENDING)))) + "<label>Choose Payment Status</label></div>"

		customizations
	end

=begin
	## if the root is an order, we don't want the add new button.
	## why not ?
	def add_new_object(root,collection_name,scripts,readonly)
			 
		if root =~ /order/
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
=end

	## @called_from : concerns/order_concern.rb#generate_receipt_pdf
	## @return[String] : the name of the patient or organization to whom the receipt is being made.
	def get_payable_by
		unless self.payable_from_patient_id.blank?
			Patient.find(self.payable_from_patient_id).name
		else
			unless self.payable_from_organization_id.blank?
				Organization.find(self.payable_from_organization_id).name
			end
		end
	end 


	## do we have a receipt object.
	## it contains payments.
	## and is from one organization -> to another organization.
	## that way we can see it at least.
	## and simplify things a little.
	## and we can keep a tally thereof.
	## so let there be a receipt object.
	## and you call generate pdf on that.
	## so this will complicate things a bit.
	## how to do prepaid ?
	## there should be a policy.
	## this will have to be embedded in that organization.
	## payment policy.
	## and it can check pending.
	## so an order will be created for a report called -> pre paid pack 
	## 200 tests, or 10000, whichever lasts longer.
	## to outsource -> first check its policy -> then redirect to payment.
	## payment is made -> what is the pending balance.
	## so a bill is generated
	## whether to catch that payment or not.
	## but it is possible.
	## now question is whether they have balance or not.
	## again depends on policy.
	## we cannot recalculate it each time.
	## it will take too long.
	## store it in the latest order.
	## best way
	## current total pending balance.
	## so you get the latest order =>
	## organization level -> don't want to update two documents.
	## before starting, you take the last 
	## we want to get_balance -> for a particular organization.
	## how do we do that ?
	## we aggregate it each time.
	## so this is a little shitty.
	## so we want to aggregate the system.
	## so all the payments if made will be aggregated.
	## we go on reads.
	## do you want seperate receipts.
	## okay so we have seperate receipts -> making things easier to view.
	## 

	#################################################################
	##
	##
	## ACCOUNTING AND PENDING BALANCE.
	##
	##
	#################################################################
	

	## let me create twenty orders.
	## in 3 hours i can do this.
	## one of those hours is already gone.

	## and pdf generation.
	## and online payment mechanism
	## what hook to call before creating payment.

	def is_cancelled?
		self.status == CANCELLED
	end

	def is_approved?
		self.status == APPROVED
	end

	def is_pending?
		self.status == PENDING
	end

	def is_a_bill?
		self.payment_type == BILL
	end

	def is_a_discount?
		self.payment_type == DISCOUNT
	end

	def is_a_payment?
		self.payment_type == PAYMENT
	end

	def is_from_balance?
		self.payment_type == FROM_BALANCE
	end

	def cancel
		self.status = CANCELLED
	end

	def approve
		self.status = APPROVED
	end

	def is_cash?
		self.payment_mode == CASH
	end

	def is_card?
		self.payment_mode == CARD
	end

	def is_cheque?
		self.payment_mode == CHEQUE
	end

	def is_online?
		self.payment_mode == ONLINE
	end

	def is_balance?
		self.payment_mode == BALANCE
	end

	def is_physical?
		(is_cash?) || (is_card?) || (is_cheque?)
	end

end
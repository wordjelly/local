require 'elasticsearch/persistence/model'
module Concerns::PayUMoneyConcern
  	extend ActiveSupport::Concern

  	included do
   		DEFAULT_PRODUCT_INFO = "order"
   		DEFAULT_FIRST_NAME = "pathofast"
   		DEFAULT_EMAIL = "supportpathofast.com"
   		PAYUMONEY_PAYMENT_STATUS_SUCCESS = "success"
      TEST_SALT = "salt"
      TEST_KEY = "key"
      TEST_TXN_ID = "id"
   		validate :callback, :unless => Proc.new{|c| c.incoming_hash.blank?}
   		before_validation do |document|
   			if document.new_record?
   				document.set_outgoing_hash
   			end
        document.compare_hashes
   		end
  	end

    def compare_hashes
      puts "came to compare hashes --->"
      puts "payumoney payment status: #{self.payumoney_payment_status}"
      unless (self.payumoney_payment_status.blank? && self.incoming_hash.blank?)
        if self.payumoney_payment_status === PAYUMONEY_PAYMENT_STATUS_SUCCESS  && self.incoming_hash === callback_calc_hash 
          ## APPROVED CONSTANT IS DEFINED IN PAYMENT.
          self.status = Business::Payment::APPROVED
        end
      end
    end

  	def get_first_name
  		unless self.created_by_user.blank?
  			self.created_by_user.email || DEFAULT_EMAIL
  		else
  			DEFAULT_EMAIL
  		end
  	end

  	def get_email
  		unless self.created_by_user.blank?
  			self.created_by_user.name || DEFAULT_FIRST_NAME
  		else
  			DEFAULT_FIRST_NAME
  		end
  	end

  	def get_product_info
  		DEFAULT_PRODUCT_INFO
  	end

  	def get_udf5
  		"BOLT_ROR_KIT"
  	end

  	## this is before_validation if its a record.
  	def set_outgoing_hash
      
  		data = 	self.class.get_payumoney_key + "|" + self.id.to_s + "|" + self.amount.to_s + "|" + get_product_info + "|" + get_first_name + "|" + get_email + "|||||" + get_udf5 + "||||||" + self.class.get_payumoney_salt

  		self.outgoing_hash = Digest::SHA512.hexdigest(data)
  	end

    def callback_calc_hash
      data = "|||||" + get_udf5 + "|||||" + get_email + "|" + get_first_name + "|" + get_product_info + "|" + self.amount.to_s + "|" + self.id.to_s + "|" + self.class.get_payumoney_key 
      
      calc_hash = Digest::SHA512.hexdigest(self.class.get_payumoney_salt + "|" + self.payumoney_payment_status + "|" + data)
     
      calc_hash
    end

    ## this is a validation.
  	def callback 	
  		if self.payumoney_payment_status === PAYUMONEY_PAYMENT_STATUS_SUCCESS  && self.incoming_hash === callback_calc_hash	
  	     


    	else
  			self.errors.add(:incoming_hash,"Payment gateway error: hash mismatch")
  		end
 	  end 

    module ClassMethods
        
      def get_payumoney_salt
        Rails.env.test? ? Concerns::PayUMoneyConcern::TEST_SALT : ENV["PAYUMONEY_SALT"]
      end

      def get_payumoney_key
        Rails.env.test? ? Concerns::PayUMoneyConcern::TEST_KEY : ENV["PAYUMONEY_KEY"]
      end

    end

end
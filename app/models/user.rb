#require "elasticsearch/persistence/model"
class User 

	include Auth::Concerns::UserConcern
	
  include Auth::Concerns::SmsOtpConcern
  
  include Concerns::OrganizationConcern

  create_es_index({
        index_name: "pathofast-users",
        index_options:  {
                settings:  {
                index: Auth::Concerns::EsConcern::AUTOCOMPLETE_INDEX_SETTINGS
              },
              mappings: {
                  "document" => {
                      properties: {
                        tags:  {
                            type: "text",
                            analyzer: "nGram_analyzer",
                            search_analyzer: "whitespace_analyzer"
                          },
                          public: {
                            type: "keyword"
                          },
                          resource_id: {
                            type: "keyword"
                          },
                          document_type: {
                            type: "keyword"
                          },
                          organization_id: {
                            type: "keyword"
                          },
                          role: {
                            type: "keyword"
                          },
                          first_name: {
                            type: "keyword"
                          },
                          last_name: {
                            type: "keyword"
                          },
                          address: {
                            type: "keyword"
                          },
                          sex: {
                            type: "keyword"
                          },
                          date_of_birth: {
                            type: "date"
                          }
                      }
                  }
              }
        }
  })


  field :approved_patient_ids, type: Array, :default => []

  field :rejected_patient_ids, type: Array, :default => []

  attr_accessor :pending_patients

  ## so let me design the organization controller.
  ## first let us design the user roles.
  ## for the base controller.
  ## inclusive of permissions.
  ## if he creates, he can add all the details of that organization.

	##########################################################
	##
	##
	## METHODS REQUIRED FOR WORDJELLY AUTH.
	##
	##
	##########################################################

	def send_sms_otp
      super
      OtpJob.perform_later([self.class.name.to_s,self.id.to_s,"send_sms_otp"])
    end

    def verify_sms_otp(otp)
        super(otp)
        OtpJob.perform_later([self.class.name.to_s,self.id.to_s,"verify_sms_otp",JSON.generate({:otp => otp})])
        
    end

    def additional_login_param_format   
        if !additional_login_param.blank?
          
          if additional_login_param =~/^([0]\+[0-9]{1,5})?([7-9][0-9]{9})$/
            
          else
            
            errors.add(:additional_login_param,"please enter a valid mobile number")
          end
        end
    end 

    def send_devise_notification(notification, *args)
        #puts "sending devise notification."
        devise_mailer.send(notification, self, *args).deliver_later
    end

    def send_reset_password_link
      super.tap do |r|
        if r
            notification = Noti.new
            resource_ids = {}
            resource_ids[User.name] = [self.resource_id]
            notification.resource_ids = JSON.generate(resource_ids)
            notification.objects[:payment_id] = r
            notification.save
            Auth::Notify.send_notification(notification)
            
        else
          puts "no r."
        end
      end
    end

	  def as_indexed_json(options={})
        self.attributes.merge({document_type: Auth::OmniAuth::Path.pathify(self.class.name.to_s)}).except("_id")
    end

    ############################################################
    ##
    ## 
    ## CALLBACKS
    ##
    ##
    ############################################################
    after_find do |document|
      document.set_patients_pending_approval
    end

    ############################################################
    ##
    ##
    ##
    ## GET PENDING PATIENTS.
    ##
    ##
    ############################################################
    def set_patients_pending_approval
      ## search patients, which are not in the ones rejected, 
      ## and not in the ones approved
      ## but have the same mobile number
      ## we have either email or additional login param.
      ## so we search for patients where either email is email or additional login param is additional login param.
      should_clauses = []

      if (self.email && self.confirmed?)
        should_clauses << {
          term: {
            email: self.email
          }
        }
      end

      if ((self.additional_login_param) && (self.additional_login_param_status == 2))
        should_clauses << {
          term: {
            mobile_number: self.additional_login_param
          }
        }
      end

      search_results = Patient.search({
        query: {
          bool:{
            must: [
              {
                bool: {
                  minimum_should_match: 1,
                  should: should_clauses
                }
              }
            ],
            must_not: [
              {
                ids: {
                  values: self.rejected_patient_ids
                }
              },
              {
                ids: {
                  values: self.approved_patient_ids
                }
              }
            ]
          }
        }
      })
      self.pending_patients = []
      search_results.response.hits.hits.each do |hit|
        self.pending_patients << Patient.find(hit["_id"])
      end
    end

    ##############################################
    ##
    ##
    ##
    ## METHODS TO GENERATE DUMMY USERS.
    ##
    ##
    ##
    ##############################################
      
    def self.create_test_user_with_email(email)
      u = User.new
      u.email = email
      u.password = "cocostan111"
      u.password_confirmation = "cocostan111"
      u.confirm
      puts u.errors.full_messsages unless u.errors.full_messages.blank?
      u.save
      puts u.errors.full_messsages unless u.errors.full_messages.blank?
    end

    def self.create_test_users
      User.es.index.delete
      User.es.index.create
      User.delete_all
      create_test_user_with_email("bhargav.r.raut@gmail.com")
      create_test_user_with_email("icantremember111@gmail.com")
    end

    alias name full_name
	
end
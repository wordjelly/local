#require "elasticsearch/persistence/model"
class User 

	include Auth::Concerns::UserConcern
	
  include Auth::Concerns::SmsOtpConcern
  
  include Concerns::OrganizationConcern


  ## the index name specified here, getting a prefix of
  ## pathofast_
  ## so the final index name becomes: pathofast_pathofast-users
  create_es_index({
        index_name: "pathofast-users",
        index_options:  {
                settings:  {
                index: Auth::Concerns::EsConcern::AUTOCOMPLETE_INDEX_SETTINGS
              },
              mappings: {
                  "user" => {
                      properties: {
                        search_all: { 
                          type: 'text', 
                          analyzer: 'nGram_analyzer', 
                          search_analyzer: "whitespace_analyzer"
                        },
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
                          first_name: {
                            type: "keyword",
                            copy_to: 'search_all'
                          },
                          last_name: {
                            type: "keyword",
                            copy_to: 'search_all'
                          },
                          address: {
                            type: "keyword"
                          },
                          sex: {
                            type: "keyword"
                          },
                          date_of_birth: {
                            type: "date"
                          },
                          organization_members: {
                            type: 'nested',
                            properties: {
                              organization_id: {
                                type: 'keyword'
                              },
                              employee_role_id: {
                                type: 'keyword'
                              },
                              created_by_this_user: {
                                type: 'keyword'
                              }
                            }
                          }
                      }
                  }
              }
        }
  })


  field :approved_patient_ids, type: Array, :default => []

  field :rejected_patient_ids, type: Array, :default => []

  attr_accessor :pending_patients

  ## the qualification and signature of the doctor
  ## it is a Credential Object.
  attr_accessor :credential 

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
        self.attributes.merge({document_type: Auth::OmniAuth::Path.pathify(self.class.name.to_s)}).except("_id").merge({"organization_members" => self.organization_members})
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
      document.load_credentials
    end

    #######################################################
    ##
    ##
    ## LOAD CREDENTIALS
    ##
    ##
    #####################################################

    ## @return[nil]
    ## sets the credential associated with this user
    def load_credentials
      puts "came to lead credentials------------------->"
      search_request = Credential.search({
        query: {
          term: {
            user_id: self.id.to_s
          }
        }
      })
      if search_request.response.hits.hits.size >= 1
            #puts "got a credential"
            credential = Credential.new(search_request.response.hits.hits[0]["_source"])
            credential.id = search_request.response.hits.hits[0]["_id"]
            credential.run_callbacks(:find)
            self.credential = credential
      end
      puts "Self credential is:"
      puts self.credential.to_s
    end

    ## what next
    ## we have done signature.
    ## should i check report generation.
    ## okay we make two labs.
    ## and get on with it.
    ## we have to explore all the options.
    ## incorporte credential in the report footers.
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
    ## FOR PROFILE
    ##
    ##
    ##############################################
    def attributes_to_return_with_profile
      ## for these organization members, we can load those organizations
      ## or we can tell him to get that organizaiton.
      ## whichever one is ok.
      ## he will need the name.
      ## since name id does not connect.
      ## and only those where he has been accepted.
      self.attributes.slice(*[:first_name,:last_name,:date_of_birth,:address,:sex]).merge(organizations: self.organization_members.map{|c| c = c.organization})
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
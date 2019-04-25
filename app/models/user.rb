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
                  "document" => Auth::Concerns::EsConcern::AUTOCOMPLETE_INDEX_MAPPINGS
            }
        }
  })

  ## so we now will be able to search for users with organization ids.

  PATIENT = "Patient"

  LAB_OWNER = "Lab Owner"

  DOCTOR = "Doctor"

  field :role, type: String, :default => PATIENT

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
        {
            tags: self.tags,
            public: self.public,
            document_type: Auth::OmniAuth::Path.pathify(self.class.name.to_s),
            resource_id: self.resource_id,
            resource_class: self.resource_class,
            organization_id: self.organization_id
        }
    end
	
end
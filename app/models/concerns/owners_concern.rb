module Concerns::OwnersConcern

	extend ActiveSupport::Concern

	## 1 -> public
	## 0 -> not public.
	## set_model in base_controller_concern, adds an or clause as public -> 1, for every query.
	## so that if a model is there, where the requesting user is not the creating user, or belonging to the creating organization, it can still see this record, if this record is public.
	## this will also help at search time, the same clause can be used.
	PUBLIC_OPTIONS = [0,1]

	IS_PUBLIC = 1

	IS_PRIVATE = 0

	included do 

		include ActiveModel::Validations
  		include ActiveModel::Validations::Callbacks

		attribute :owner_ids, Array, mapping: {type: 'keyword'}
		
		## skip owners validations.
		attr_accessor :skip_owners_validations

		attr_accessor :created_by_user

		attr_accessor :current_user
 
		attr_accessor :organization

		attribute :created_by_user_id

		attribute :currently_held_by_organization, String, mapping: {type: 'keyword'}

		validate :created_user_exists, :if => Proc.new{|c| c.skip_owners_validations.blank?}
			
		validate :organization_users_are_enrolled_with_organization

		attribute :public, Integer, mapping: {type: 'integer'}, default: Concerns::OwnersConcern::IS_PRIVATE

		## for what?
		## it could be creating an organization itself.
		## why does it need to have a role?
		### CHECKS THAT THERE IS A CREATED_USER, AND THAT IT HAS A ROLE.
		def created_user_exists

			if self.created_by_user.blank?
				self.errors.add(:created_by_user,"There is no creating user")
			#else
			#	if self.created_by_user.role.blank?
			#		self.errors.add(:created_by_user,"You don't have a role, please go to your profile link, and add a Role")
			#	end
			end
		end

		## depending on the context.
		## we have to show custom options.
		## make it easier to add more reprots
		## see why there is duplication of the required reports
		## and change the name of categ
		## assign public roles by default.
		## CHECKS THAT IF THE ROLE IS OF AN ORGANIZATION, THEN THE USER IS VERIFIED, AS BELONGING TO IT.
		## this ensures that only verified organization users can interact with resources. 
		def organization_users_are_enrolled_with_organization
			
			if (self.new_record? && self.class.name == "Organization")
			
			elsif !self.skip_owners_validations.blank?
			
			else
				#puts "the created by user is: #{self.created_by_user}"
				#puts "class is: #{self.class.name}, skip validations is: #{self.skip_owners_validations}"
				if !self.created_by_user.has_organization?
					self.errors.add(:created_by_user,"you have not yet been verified as belonging to this organization")
				end
			end
		end

		def add_owner_ids
			if self.owner_ids.blank?
				self.owner_ids = []
				unless self.created_by_user.blank?
					## in case the user is creating an organiztion,
					## it will not have an organization id itself.
					## since the organiztion has not yet even been created
					## that's why we started the system of adding the creating users id
					## to the owner ids of any document it creates. 
					## this part will change a bit.
					self.owner_ids << [self.created_by_user.id.to_s]
					unless self.created_by_user.organization.blank?
						
						self.owner_ids << [self.created_by_user.organization.id.to_s]
						self.currently_held_by_organization = created_by_user.organization.id.to_s
						
					end
				end
				## if the document is an organization, its own id 
				## is added as an owner
				## because when users belonging to this organization
				## try to access it, they will be using their organization id 
				## in the authorization query.
				## okay this is understandable.
				if self.class.name == "Organization"
					if self.owner_ids.blank?
						self.owner_ids << self.id.to_s
					end
				end
			end
		
			self.owner_ids.flatten!
		end


		## this also should be methodized to enable overrides.
		#before_save do |document|
			
		#end

		#this callback should also cascade.
		#after_find -> cascade callbacks on after_find.
		#otherwise this won't work.

		before_validation do |document|
			document.add_owner_ids
			unless document.class.name == "Organization"
				#puts "doing before validation on class: #{document.class.name} with currently held by organization :#{document.currently_held_by_organization}"
				unless document.currently_held_by_organization.blank?
					document.organization = Organization.find(document.currently_held_by_organization)
					#puts "the organization becomes: #{document.organization.id.to_s}"
				end
			end
		end

		# so these callbacks i have to manage.
		# and sort this mess out now.
		# we give a created_by_user id for all the modules ?
		# and assign current user seperately
		# and deal with the callback hell

		## so this callback is not getting triggered on the 
		## report.
		## to load the organization.
		## so we are not being able to cascade these callbacks.
		after_find do |document|	
			## so this is being done after find.
			## why was it not cascaded ?
			## the callback 
			## it would have gotten set.
			#puts "Came to after find with class: #{document.class.name}"		
			unless document.class.name == "Organization"
				unless document.currently_held_by_organization.blank?
					#puts "doing after find on class: #{document.class.name}"
					document.organization = Organization.find(document.currently_held_by_organization)
					#puts "the organization becomes: #{document.organization.id.to_s}"
				end
			end
		end

		def created_by_user=(created_user)
			self.current_user = created_user
			@created_by_user = created_user
		end

	end

	## an item cannot be added to a transaction unless that transaction has received some items.
	## secondly it has to know how many items were created from 
	## that transaction.
	## so the transfer adds the item as an owner.
	## now we have to decide what all can be modified.
	## we can additionally define, what the original
	## creator's organization can modify, 
	## and what other organizations can modify/.
	## this can be defined in the permissions.
	## refactor is completed.
	def add_owner(user_id)
		begin
			u = User.find(user_id)
			self.owner_ids << u.organization.id.to_s
			self.save
		rescue
			self.errors.add(:owner_ids, "could not add the recipient to the owner ids of the object #owners_concern.rb")
		end
	end

	## whether to show the public form or not.
	## @return[Boolean] true/false : if we have to show the form selection 
	## for visibility.
	def show_visibility_selection
		false
	end

	## @called_from : receipt#validations.
	def has_created_by_user_id?
		!self.created_by_user_id.blank?
	end


end
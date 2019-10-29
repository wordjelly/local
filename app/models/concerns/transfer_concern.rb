module Concerns::TransferConcern

	extend ActiveSupport::Concern

	## so for the statuses and the sop's
	## we have to have these options.
	## also report formats.
	## and test formats.
	## reporting criteria.

	included do 

		attr_accessor :to_user
		## what is the object that is being transferred ?
		attr_accessor :transferred_object
		## this object has to also be loaded.
		## and its after_find callbacks have to be called.
	end	

	## so then what?
	## can the current user transfer this object ?
	## 

	## a user can transfer an object, if its organization owns
    ## that item, or it is the creator of that object.
    ## @param[User] user: the current user.
    def can_transfer?(user)
        puts "the owner ids are:"
        puts self.owner_ids.to_s
        puts "the user organization id is:"
        puts user.organization.id.to_s
        puts "the user id is:"
        puts user.id.to_s
        puts "-----------------------------------------------"
    	if self.owner_ids.include? user.organization.id.to_s
    		return true
    	elsif self.owner_ids.include? user.id.to_s
    		return true
    	end
    end

    ## do we need to add the ownership?
    ## when we transfer an object, we may need to 
    def ownership_addition_necessary?(to_user)
    	if self.owner_ids.include? to_user.organization.id.to_s
    		false
    	else
    		true
    	end
    end

    def build_add_owner_request(to_user)
    	source = """
			ctx._source.owner_ids.add(params.organization_id);
			ctx._source.currently_held_by_organization = params.organization_id;
		"""

		params = {organization_id: to_user.organization.id.to_s}

		update_hash = {
			update: {
				_index: self.class.index_name,
				_type: self.class.document_type,
				_id: self.id.to_s,
				data: { 
					script: 
					{
						source: source,
						lang: 'painless', 
						params: params
					}
				}
			}
		}
    end

    ## @param[User] current_user : the current user who is doing the interaction with the API.
    ## @param[User] to_user : the user to whom the document is being transferred.
    def transfer(current_user,to_user)
        puts "transferring from------------->"
        puts current_user.email.to_s
        puts "transferring to:"
        puts to_user.email.to_s
        puts self.class.name.to_s
    	reqs = [
    		build_add_owner_request(to_user)
    	]
        puts "-------- calling transfer ------------- "
        #puts "current user is: #{puts current_user.to_s}"
        #puts "to user is: #{puts to_user.to_s}"
        #puts "can transfer: #{puts can_transfer?(current_user)}"
        #puts "ownership_addition_necessary : #{puts ownership_addition_necessary?(to_user)}"
    	#puts "get components for transfer is:"
        #puts get_components_for_transfer.to_s
        if can_transfer?(current_user) && ownership_addition_necessary?(to_user)
    		get_components_for_transfer.each do |obj|
    			reqs.push(obj.transfer(current_user,to_user))
    		end
    	end
    	reqs.flatten
    end

    def get_components_for_transfer
        []
    end

end
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

    ## override in the object that implements this concern.
    def get_components_for_transfer
    	## so if its an item group get it.
    	## etc.
    	## if its a transaction, then get all the item groups.
    	## and their constituents.
    	## that's what an item transfer does.
    end

    def build_add_owner_request(to_user)
    	source = """
			ctx._source.owner_ids.add(params.organization_id)
			cts._source.currently_held_by_organization = params.organization_id
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
    	reqs = [
    		build_add_owner_request(to_user)
    	]
    	if can_transfer?(current_user) && ownership_addition_necessary?(to_user)
    		get_components_for_transfer.each do |obj|
    			reqs.push(obj.transfer(current_user,to_user))
    		end
    	end
    	reqs.flatten
    end


end
require 'test_helper'
 
class OrderTest < ActiveSupport::TestCase
   
    setup do 

    end
  
   
    ###############################################################
    ##
    ##
    ## APPROVED PENDING CANCELLED.
    ## who can approve, who can cancel and who can set a payment
    ## as pending
    ## so let us say first of all who can add the payment.
    ## so we have three scenarios.
    ## the way payments are made through patient organizations.
    ## basically the patient also has an organization.
    ## patient makes order(Basically his orgnaization does that)
    ## the report is outsourced via base, to pathofast
    ## or any company.
    ## or i am a doctor/lab.
    ## who can pay the bill.
    ## the creating organization can make a payment
    ## who can add a payment to the receipt and what type of payment can 
    ## they add.
    ## so i made an order for a patient
    ## i can add a payment to any receipt
    ## can the patient make that payment.
    ## so whoever is the payable_to => can add any type of payment, into that receipt.
    ## yes but what about access control ?
    ## let us say i created an order.
    ## as pathofast
    ## i outsourced to x/y/z
    ## so z can add a payment(say cash)
    ## to that order.
    ## so cash/card/cheque type of payments can only be added to a given receipt by the organization payable to;
    ## online payments can be added by organization payable from
    ## suppose he wants to say that payment was transferred.
    ## then that also can only be done by him
    ## he can make online.
    ## secondly -> so that is for cash/card etc.
    ## balance/online can be made by the payable from.
    ## first we sort this out
    ## 
    ##
    ##
    ###############################################################


end
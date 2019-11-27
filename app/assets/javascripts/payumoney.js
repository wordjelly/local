function launchBOLT()
// first create an online payment.
// then we give a button to go for online
// the txnid is the id of the payment.
// the surl and furl are populated with default values
// as they 
// so we can have
// the hash should be calculated on payment creation.
// so there is no need to generate it each time.
//  
// udf5, surl, furl, productinfo, phone, email, firstname, 
{
	bolt.launch(
		{
			key: $('#key').val(),
			txnid: $('#txnid').val(), 
			hash: $('#hash').val(),
			amount: $('#amount').val(),
			firstname: $('#fname').val(),
			email: $('#email').val(),
			phone: $('#mobile').val(),
			productinfo: $('#pinfo').val(),
			udf5: $('#udf5').val(),
			surl : $('#surl').val(),
			furl: $('#surl').val()
		},
		{ 
			responseHandler: function(BOLT){
				console.log( BOLT.response.txnStatus );		
				if(BOLT.response.txnStatus != 'CANCEL')
				{
					//Salt is passd here for demo purpose only. For practical use keep salt at server side only.
					var fr = '<form action=\"'+$('#surl').val()+'\" method=\"post\">' +
					'<input type=\"hidden\" name=\"key\" value=\"'+BOLT.response.key+'\" />' +
					'<input type=\"hidden\" name=\"salt\" value=\"'+$('#salt').val()+'\" />' +
					'<input type=\"hidden\" name=\"txnid\" value=\"'+BOLT.response.txnid+'\" />' +
					'<input type=\"hidden\" name=\"amount\" value=\"'+BOLT.response.amount+'\" />' +
					'<input type=\"hidden\" name=\"productinfo\" value=\"'+BOLT.response.productinfo+'\" />' +
					'<input type=\"hidden\" name=\"firstname\" value=\"'+BOLT.response.firstname+'\" />' +
					'<input type=\"hidden\" name=\"email\" value=\"'+BOLT.response.email+'\" />' +
					'<input type=\"hidden\" name=\"udf5\" value=\"'+BOLT.response.udf5+'\" />' +
					'<input type=\"hidden\" name=\"mihpayid\" value=\"'+BOLT.response.mihpayid+'\" />' +
					'<input type=\"hidden\" name=\"status\" value=\"'+BOLT.response.status+'\" />' +
					'<input type=\"hidden\" name=\"hash\" value=\"'+BOLT.response.hash+'\" />' +
					'</form>';
					var form = jQuery(fr);
					jQuery('body').append(form);								
					form.submit();
				}
			},
			catchException: function(BOLT){
	 			alert( BOLT.message );
			}
		}
	);
}
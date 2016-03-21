require 'net/http'
require 'json'
require 'openssl'

class Http
  POST    = "POST"
  GET     = "GET"

  #
  # Create a new HTTP object based on the settings set in @link Settingsend.
  # @param settings
  #
  def initialize( settings ) 
    @method   = settings.getMethod()
    @timeout  = settings.getTimeout()
  end

  #
  # Processes the HTTP request.
  #
  def run() 
    startTs = (Time.now.to_f * 1000.0).to_i

    if ( @method != POST ) # force POST
      raise "GET not supported"
    end
    
    uri = URI.parse(@endpoint)
    request = Net::HTTP::Post.new(uri.request_uri, initheader = {'Content-Type' => 'application/json'})
    request.body = @request

    response = Net::HTTP.start(uri.hostname,uri.port, :read_timeout => 20000,:use_ssl => true) { |http| http.request(request) }

    @rawResponse  = response.body
    @contentType  = response.content_type
    @httpCode     = response.code

    if ( response.message != "" ) 
      @httpResponse = response.message
    else
      @httpResponse = @httpCode
    end
    @duration = (Time.now.to_f * 1000.0).to_i - startTs
  end

  def testRun()
    @rawResponse = '{"rcode":"000","rmsg":"Approved T63362", "pg_id":"8af556ae480811e484b20c4de99f0aaf"}'
    @httpCode = 200
    @duration = 500
    @contentType = "application/json"
  end

  def setRequestString( requestString )
    @request = requestString
  end

  def setHost( endpoint )
    @endpoint = endpoint
  end

  def getRequestString()
    @request
  end

  def getHttpCode() 
    @httpCode
  end

  def getHttpText()
    @httpResponse
  end

  def getResponseContentType()
    @contentType
  end

  def getRawResponse()
    @rawResponse
  end

  def getDuration()
    @duration
  end
end

class CcData

  def initialize(cardNumber = '', expDate = '', cvv = '')
    @token = ''
    setCcNum(cardNumber)
    setExpDate(expDate)
    setCvv(cvv)
    self
  end

  def setCcNum(cardNumber) 
    @ccNum = cardNumber
    self
  end

  def setExpDate(expDate)
    @expDate = expDate
    self
  end

  def setCvv(cvv)
    @cvv = cvv
    self
  end

  def setToken(token)
    @token = token
    self
  end

  def getCcNum() 
    @ccNum
  end

  def getExpDate()
    @expDate
  end

  def getCvv() 
    @cvv
  end

  def getToken() 
    @token
  end
end

# settings 
class GatewaySettings 

  QP_TEST = "https://api-test.qualpay.com"
  QP_PROD = "https://api.qualpay.com"

  #
  # Creates default gateway settings of method type POST, a timeout of 20s, an endpoint of the QA environment.<br />
  # The default URL is set to live.
  #
  def initialize(url = QP_TEST, id = '', key = '') 
    @method         = Http::POST
    @timeout        = 20000         # 20 seconds
    @verbose        = false
    @url            = url
    @merchantId     = id
    @securityKey    = key
  end

  #
  # Sets the merchant ID and security key which are used to authenticate with the Payment Gateway
  # @param id
  # @param key
  #
  def credentials(id, key) 
    @merchantId = id
    @securityKey = key
    self
  end

  def method( method ) 
    if( method != Http::POST ) 
      raise "Qualpay Payment Gateway only supports POST transactions."
    end
    self
  end

  def timeout( timeout ) 
    @timeout = timeout
    self
  end

  def verbose(verbose) 
    @verbose = verbose
    self
  end
  
  def isVerbose()
    @verbose
  end

  def url(url) 
    @url = url
    self
  end

  # @return The Merchant ID
  def getMerchantId() 
    @merchantId
  end

  def getMethod() 
    @method
  end

  # @return the Security Key
  def getSecurityKey() 
    @securityKey
  end

  # @return the timeout value
  def getTimeout() 
    @timeout
  end

  # @return the URL
  def getUrl() 
    @url
  end

end

class TransactionType 
  # An authorization only.
  AUTH        = "auth"
  # Validates the card account is open. Not supported by all issuers.
  VERIFY      = "verify"
  # An authorization followed by an automatic capture.
  SALE        = "sale"
  # Captures an authorization for funding.
  CAPTURE     = "capture"
  # Cancels a transaction authorized same-day.
  VOID        = "void"
  # Using an authorization's pg id, a void is performed (if same-day) or credit is given (if the transaction was captured, and funded).
  REFUND      = "refund"
  # An unmatched credit, requiring a full card number.
  CREDIT      = "credit"
  # A forced-entry transaction using an approval code.
  FORCE       = "force"
  # The transaction id returned by this request may be sent in the card_id field, replacing any card number field.
  TOKENIZE    = "tokenize"
  # Attempts to settle the current batch. 
  BATCH_CLOSE = "batchClose"

  def self.getPath( tranType ) 
    if( !TransactionType.const_defined?(tranType.upcase) )
      raise "Invalid transaction type '" + tranType + "'"
    end
    '/pg/' + tranType
  end
end

#
# Gateway request object used to contain the request params
#
class GatewayRequest 
  CARD_PRESENT        = nil
  MAIL_PHONE_ORDER    = '1'
  RECURRING           = '2'
  INSTALLMENT         = '3'
  ECOMMERCE_3DS_FULL  = '5'
  ECOMMERCE_3DS_MERCH = '6'
  ECOMMERCE           = '7'

  def initialize( reqType )
    @lineItems  = Array.new
    @params     = Hash.new 
    @type       = reqType
    setParameter("developer_id","qp-pg-sdk-ruby")
    motoEcommInd(GatewayRequest::ECOMMERCE)     # default to ecommerce
  end

  #
  # Adds a level 3 line item to the request.
  # @param lineItem
  # @return
  #
  def addLineItem( lineItem ) 
    @lineItems << lineItem
    self
  end

  def getType() 
    @type
  end
  
  def getLineItems()
    @lineItems 
  end
  
  def getPgId() 
    @pgId
  end

  def setPgId(id) 
    @pgId = id
    self
  end

  #
  # Sets the @link CcDataend object for this transaction.
  # @param ccData The object containing the card data.
  #
  def cardData( ccData ) 
    if(ccData.getToken() != '') 
      setParameter("card_id",ccData.getToken())
    else 
      # Attempt to sanitize
      ccNumber = ccData.getCcNum().gsub(/\D/, '')
      setParameter("card_number",ccNumber)
    end

    if ( ccData.getExpDate() != '') 
      setParameter("exp_date",ccData.getExpDate())
    end
    if( ccData.getCvv() != '' ) 
      setParameter("cvv2",ccData.getCvv())
    end
    self
  end

  #
  # Sets the request amount.
  # @param amount The requested amount.
  #
  def amount( amount ) 
    setParameter("amt_tran",amount)
    self
  end

  def amountTax( amount ) 
    setParameter("amt_tax",amount)
    self
  end

  def avsAddress( addr ) 
    setParameter("avs_address",addr[0..19])
    self
  end

  def avsData( addr, zip ) 
    avsAddress( addr )
    avsZip( zip )
    self
  end

  def avsZip( zip ) 
    setParameter("avs_zip",zip.gsub(/\D/, '')[0..8])
    self
  end

  def purchaseId( purchId ) 
    setParameter("purchase_id",purchId[0..24])
    self
  end

  def merchRefNum( merchRefNum ) 
    setParameter("merch_ref_num",merchRefNum[0..127])
    self
  end

  def motoEcommInd( motoEcommInd ) 
    setParameter("moto_ecomm_ind",motoEcommInd)
    self
  end
  
  def getParameter( name ) 
    @params[name]
  end
  
  def getParameters()
    @params
  end  

  def setParameter( name, value ) 
    @params[name] = value
    self
  end
end

class GatewayResponse 

  def initialize(response, httpCode, httpText, rawResponse, duration, isApproved) 
    @response     = response
    @httpCode     = httpCode
    @httpText     = httpText
    @rawResponse  = rawResponse
    @duration     = duration
    @isApproved   = isApproved
  end

  #
  # Returns true on an approved request (an response code of 000, or 085 in the case of a validation).
  # @return true on a valid request
  #
  def isApproved() 
    @isApproved
  end

  #
  # Get the Gateway response code. May not be numeric only (such as the 0N7 CVV mismatch result code).<br />
  # The return cannot be an integer; non numeric codes are possible, such as "0N7" (for cvv mismatch).
  # @return The Gateway's error code result
  #
  def getResponseCode() 
    @response["rcode"]
  end

  #
  # Get the textual response returned by the Gateway.
  # @return The Gateway's text description of the result
  #
  def getAuthResponse() 
    @response["rmsg"]
  end

  #
  # Gets the transaction ID returned with every request.
  # @return The transaction ID generated by the Gateway
  #
  def getPgId() 
    @response["pg_id"]
  end

  # @return Gets the authorization code from an approved transaction.
  def getAuthCode() 
    @response["auth_code"]
  end

  # @return Gets the CVV2 result code from an approved transaction.
  def getCvv2Result() 
    @response["auth_cvv2_result"]
  end

  # @return Gets the AVS result code from an approved transaction.
  def getAvsResult() 
    @response["auth_avs_result"]
  end
  
  def getRawResponse()
    @rawResponse
  end  
  
  def getDuration()
    @duration
  end

  def toString() 
    "[Approved:" + @isApproved + "] " + "[HTTP:" + @httpCode + "] [duration:" + @duration + "ms] "
  end
end

class Gateway 

  def initialize( settings ) 
    @settings = settings
  end

  def run( requestObject ) 
    reqBody = parseRequest(requestObject)
    endpoint = parseEndpoint(requestObject)

    if ( @settings.isVerbose() ) 
      puts 'Endpoint: ' + endpoint
      puts 'Request Body: ' + reqBody
    end
    http = Http.new(@settings)
    http.setHost(parseEndpoint(requestObject))
    http.setRequestString(reqBody)
    http.run()
    resp = parseResponse(http)

    if ( @settings.isVerbose() ) 
      puts 'Response Body: ' + resp.getRawResponse()
    end

    resp
  end

  def parseEndpoint( req ) 
    uri = @settings.getUrl() + TransactionType::getPath(req.getType())

    # some URLs require a pg_id
    case req.getType()
    when TransactionType::CAPTURE, TransactionType::VOID, TransactionType::REFUND
      uri = uri + '/' + req.getPgId()
    end
    uri
  end

  def notNil( value )  
    value != nil
  end

  def parseRequest( req ) 
    req.setParameter("merchant_id",  @settings.getMerchantId())
    req.setParameter("security_key", @settings.getSecurityKey())

    if( req.getLineItems().size() > 0 ) 
      req.setParameter("line_items", req.getLineItems())
    end
    # encode the params as JSON and remove any fields with a value of null
    # req.getParameters().to_json.gsub('"\w+?"\s*:\s*null,?','')
    req.getParameters().to_json.gsub(/,\s*"[^"]+":null|"[^"]+":null,?/, '')
    # req.getParameters().to_json
  end

  def parseResponse( http ) 
    isApproved = false

    if( "application/json" != http.getResponseContentType() ) 
      respValues["rmsg"]   = "Communication Error (Unsupported response format " + http.getResponseContentType() + ")"
      respValues["rcode"]  = "999"
    else 
      responseBody = http.getRawResponse()
      if( responseBody.strip != nil ) 
        respValues = JSON.parse responseBody
        if ( respValues["rcode"] == "000" ) 
          isApproved = true
        end
      end
    end

    gResp = GatewayResponse.new(respValues,
        http.getHttpCode(),
        http.getHttpText(),
        http.getRawResponse(),
        http.getDuration(),
        isApproved
        )
    gResp
  end

  def getResponseObject( responseBody ) 
    JSON.parse responseBody    
  end
end


class UniversalLineItem 
  
  def initialize() 
    @fields = Hash.new
    debitOrCreditIndicator('D')
    quantity(1)
  end

  #
  # @param code
  # @return
  #
  def itemCommodityCode( code ) 
    setData('commodity_code',code[0..11])
    self
  end

  #
  # Set the description for this line item.
  # @param description
  # @return
  #
  def itemDescription( description ) 
    setData('description',description[0..25])
    self
  end

  #
  # Set the quantity of this line item.
  # @param quantity
  # @return
  #
  def quantity( quantity ) 
    setData('quantity',quantity.to_s.gsub(/\D/, '')[0..6])
    self
  end

  #
  # @param code
  # @return
  #
  def productCode( code ) 
    setData('product_code',code[0..11])
    self
  end

  #
  # Set the method of measuring this line item (ex. EACH, LBS, etc).
  # @param unit
  # @return
  #
  def unitOfMeasure( unit ) 
    setData('unit_of_measure',unit[0..11])
    self
  end

  #
  # Set the monetary amount for the cost per unit of measure.
  # @param cost
  # @return
  #
  def unitCost( cost ) 
    setData('unit_cost',cost)
    self
  end

  def typeOfSupply( type ) 
    setData('type_of_supply',type[0..1])
    self
  end

  #
  # Flag whether this line item is a Debit or Credit.
  # @param indicator
  # @return
  #
  def debitOrCreditIndicator( indicator ) 
    setData('debit_credit_ind', (indicator == 'C') ? 'C' : 'D')
    self
  end
  
  def setData( name, value ) 
    @fields[name] = value
  end
  
  def to_json(*a)
    @fields.to_json
  end
end

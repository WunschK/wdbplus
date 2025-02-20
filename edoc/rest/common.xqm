xquery version "3.1";

module namespace wdbRCo = "https://github.com/dariok/wdbplus/RestCommon";

declare namespace config = "https://github.com/dariok/wdbplus/config";
declare namespace http   = "http://expath.org/ns/http-client";
declare namespace rest   = "http://exquery.org/ns/restxq";

(:~
 : check whether all values in $standard are present in $input
 :
 : @param $standard xs:string* the basis for comparison
 : @param $input xs:string* the sequence to check
 : @returns xs:boolean
 :)
declare function wdbRCo:sequenceEqual($standard as xs:string*, $input as xs:string*) as xs:boolean {
  count($standard) = count($input) and
  count($standard) = count(distinct-values(($standard, $input)))
};

(:~
 : Evaluate CORS preflight requests and respond according to configuration
 :
 : @param $originHeader The value of the origin header as sent in the request
 : @param $method The HTTP method to allow for the main request
 :)
declare function wdbRCo:evaluatePreflight ( $originHeader as xs:string, $method as xs:string ) as element(rest:response) {
  let $origins := doc("../config.xml")//config:origin/text()
  
  return if ( count($origins) = 0 ) then
    <rest:response>
      <http:response status="204">
        <http:header name="Access-Control-Allow-Origin" value="*" />
        <http:header name="Access-Control-Allow-Headers" value="authorization" />
        <http:header name="Access-Control-Allow-Methods" value="{$method}" />
      </http:response>
    </rest:response>
  else if ( $originHeader = $origins ) then
    <rest:response>
      <http:response status="204">
        <http:header name="Access-Control-Allow-Origin" value="{$originHeader}" />
        <http:header name="Access-Control-Allow-Headers" value="authorization" />
        <http:header name="Access-Control-Allow-Methods" value="{$method}" />
      </http:response>
    </rest:response>
  else
    <rest:response>
      <http:response status="403" />
    </rest:response>
};

xquery version "3.1";

module namespace wdbRf = "https://github.com/dariok/wdbplus/RestFiles";

import module namespace json    = "http://www.json.org";
import module namespace wdb     = "https://github.com/dariok/wdbplus/wdb"  at "../modules/app.xql";
import module namespace xstring = "https://github.com/dariok/XStringUtils" at "../include/xstring/string-pack.xql";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace tei    = "http://www.tei-c.org/ns/1.0";
declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace http   = "http://expath.org/ns/http-client";
declare namespace meta   = "https://github.com/dariok/wdbplus/wdbmeta";
declare namespace wdbPF  = "https://github.com/dariok/wdbplus/projectFiles";

declare variable $wdbRf:server := $wdb:server;
declare variable $wdbRf:collection := collection($wdb:data);

(: get a resource by its ID – whatever type it might be :)
declare
    %rest:GET
    %rest:path("/edoc/resource/{$id}")
function wdbRf:getResource ($id as xs:string) {
  (: Admins are advised by the documentation they REALLY SHOULD NOT have more than one entry for every ID
   : To be on the safe side, we go for the first one anyway :)
  let $files := (collection($wdb:data)//id($id)[self::meta:file])
  let $f := $files[1]
  let $path := substring-before(base-uri($f), 'wdbmeta.xml') || $f/@path
  let $type := xmldb:get-mime-type($path)
  
  let $respCode := if (count($files) = 0)
  then "404"
  else if (count($files) = 1)
  then "200"
  else "500"
  
  return (
    <rest:response>
      <http:response status="{$respCode}">{
        if (string-length($type) = 0) then () else
        <http:header name="Content-Type" value="{$type}" />
      }</http:response>
    </rest:response>,
    if ($type = "application/xml")
    then doc($path)
    else util:binary-to-string(util:binary-doc($path))
  )
};
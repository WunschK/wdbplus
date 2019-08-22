xquery version "3.1";

module namespace wdbRAd = "https://github.com/dariok/wdbplus/RestAdmin";

import module namespace console = "http://exist-db.org/xquery/console"     at "java:org.exist.console.xquery.ConsoleModule";
import module namespace xstring = "https://github.com/dariok/XStringUtils" at "/db/apps/edoc/include/xstring/string-pack.xql";

declare namespace http = "http://expath.org/ns/http-client";
declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace tei  ="http://www.tei-c.org/ns/1.0";

(: endpoints to ingest entire projects by uploading directories from the browser
 : useful when ingesting existing projects into the database
 : does not do anything else, esp. does not enter files into wdbmeta.xml :)
declare
  %rest:POST("{$contents}")
  %rest:path("/edoc/admin/ingest/dir")
  %rest:query-param("collection", "{$collection}")
  %rest:query-param("name", "{$name}")
  %rest:consumes("application/xml")
  function wdbRAd:ingestXML ($contents as document-node()*, $collection as xs:string*, $name as xs:string*) {
    let $fullpath := $collection || '/' || $name
    let $collection-uri := xstring:substring-before-last($fullpath, '/')
    let $resource-name := xstring:substring-after-last($fullpath, '/')
    
    return local:store($collection-uri, $resource-name, $contents)
};

declare
  %rest:POST("{$data}")
  %rest:path("/edoc/admin/ingest/dir")
  %rest:query-param("collection", "{$collection}")
  %rest:query-param("name", "{$name}")
  %rest:consumes("application/octet-stream")
  function wdbRAd:ingest ($data as xs:string*, $collection as xs:string*, $name as xs:string*) {
    let $fullpath := $collection || '/' || $name
    let $collection-uri := xstring:substring-before-last($fullpath, '/')
    let $resource-name := xstring:substring-after-last($fullpath, '/')
    let $contents := util:base64-decode($data)
    
    return local:store($collection-uri, $resource-name, $contents)
};

declare function local:store($collection, $resource-name, $contents) {
  let $mime-type := switch (substring-after($resource-name, '.'))
    case "css" return "text/css"
    case "js" return "application/javascript"
    case "xql"
    case "xqm" return "application/xquery"
    case "html" return "text/html"
    case "gif" return "image/gif"
    case "png" return "image/png"
    case "json" return "application/json"
    case "xml" return
      if ($contents/tei:TEI) then "application/tei+xml" else "application/xml"
    case "xsl" return "application/xslt+xml"
    default return "application/octet-stream"
  let $mode := if (ends-with($resource-name, 'xql')) then "rwxrwxr-x" else "rw-rw-r--"
  let $coll := if (not(xmldb:collection-available($collection)))
    then local:createCollection($collection)
    else ()
  let $path := try {
    xmldb:store($collection, $resource-name, $contents, $mime-type)
  } catch * {
    <error>{$err:code}: {$err:description}</error>
  }
  
  return if ($path[1] instance of node())
    then (
      <rest:response>
        <http:response status="500">
          <http:header name="Content-Type" value="application/xml" />
          <http:header name="rest-status" value="REST:ERROR" />
        </http:response>
      </rest:response>,
      $path,
      console:log("error storing XML " || $mime-type || " to " || $path)
    )
    else (
      <rest:response>
        <http:response status="200">
          <http:header name="Content-Type" value="text/plain" />
          <http:header name="rest-status" value="REST:SUCCESS" />
        </http:response>
      </rest:response>,
      $path,
      sm:chown($path, "wdb:wdbusers"),
      sm:chmod($path, $mode),
      console:log("storing " || $mime-type || " to " || $path)
    )
};

declare function local:createCollection ($coll as xs:string) {
    let $target-collection := xstring:substring-before-last($coll, '/')
    let $new-collection := xstring:substring-after-last($coll, '/')
    
    return if (xmldb:collection-available($target-collection))
      then 
        (
          let $path := xmldb:create-collection($target-collection, $new-collection)
          let $chown := sm:chown($path, "wdb")
          let $chgrp := sm:chgrp($path, "wdbusers")
          
          return console:log("creating " || $new-collection || " in " || $target-collection)
        )
      else (
          local:createCollection($target-collection),
          xmldb:create-collection($target-collection, $new-collection)
      )
};
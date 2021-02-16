xquery version "3.1";

module namespace wdbRc = "https://github.com/dariok/wdbplus/RestCollections";

import module namespace console = "http://exist-db.org/xquery/console" at "java:org.exist.console.xquery.ConsoleModule";
import module namespace json    = "http://www.json.org";
import module namespace wdb     = "https://github.com/dariok/wdbplus/wdb"         at "/db/apps/edoc/modules/app.xqm";
import module namespace wdbErr  ="https://github.com/dariok/wdbplus/errors"       at "/db/apps/edoc/modules/error.xqm";
import module namespace wdbRCo  = "https://github.com/dariok/wdbplus/RestCommon"  at "/db/apps/edoc/rest/common.xqm";
import module namespace wdbRMi  = "https://github.com/dariok/wdbplus/RestMIngest" at "/db/apps/edoc/rest/ingest.xqm";
import module namespace xstring = "https://github.com/dariok/XStringUtils"        at "/db/apps/edoc/include/xstring/string-pack.xql";

declare namespace http   = "http://expath.org/ns/http-client";
declare namespace meta   = "https://github.com/dariok/wdbplus/wdbmeta";
declare namespace mets   = "http://www.loc.gov/METS/";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace tei    = "http://www.tei-c.org/ns/1.0";

declare variable $wdbRc:acceptable := ("application/json", "application/xml");

(: create a (sub-)collection :)
declare
  %rest:POST("{$data}")
  %rest:path("/edoc/collection/{$collectionID}/subcollection")
  %rest:consumes("application/json")
function wdbRc:createSubcollectionJson ( $data as xs:string*, $collectionID as xs:string ) {
  let $map := parse-json(util:base64-decode($data))
  return wdbRc:createSubcollection($map, $collectionID)
};

declare
  %rest:POST("{$data}")
  %rest:path("/edoc/collection/{$collectionID}/subcollection")
  %rest:consumes("application/xml")
function wdbRc:createSubcollectionXml ( $data as element()*, $collectionID as xs:string ) {
  let $map := map:merge(for $e in $data/* return map { $e/local-name(): $e/string() })
  return wdbRc:createSubcollection($map, $collectionID)
};

declare
  %private
function wdbRc:createSubcollection ( $collectionData as map(*), $collectionID as xs:string ) {
  if (map:size($collectionData) eq 0) then
    (
      <rest:response>
        <http:response status="400">
          <http:header name="Content-Type" value="text/plain" />
          <http:header name="Access-Control-Allow-Origin" value="*"/>
        </http:response>
      </rest:response>,
      "no configuration data submitted"
    )
  else if (not(wdbRCo:sequenceEqual(("collectionName", "id", "name"), map:keys($collectionData)))) then
    (
      <rest:response>
        <http:response status="400">
          <http:header name="Content-Type" value="text/plain" />
          <http:header name="Access-Control-Allow-Origin" value="*"/>
        </http:response>
      </rest:response>,
      "missing data; needed information: collectionName, id, name"
    )
  else if (not (collection($wdb:data)/id($collectionID)[self::meta:projectMD])) then
    (
      <rest:response>
        <http:response status="404">
          <http:header name="Content-Type" value="text/plain" />
          <http:header name="Access-Control-Allow-Origin" value="*"/>
        </http:response>
      </rest:response>,
      "no project with ID " || $collectionID || " or project not using wdbmeta.xml"
    )
  else
    let $collection := wdb:getEdPath($collectionID, true())
    
    let $parentMeta := doc($collection || "/wdbmeta.xml")
    let $errUser := not(sm:has-access(base-uri($parentMeta), "w"))
    
    let $errCollectionPresent := try {
        wdb:getEdPath($collectionData?id)
      } catch * {
        false()
      }
    
    return if ($errUser)
    then (
      <rest:response>
        <http:response status="403">
          <http:header name="Content-Type" value="text/plain" />
          <http:header name="Access-Control-Allow-Origin" value="*"/>
        </http:response>
      </rest:response>,
      "user " || sm:id()//sm:real/sm:username || " does not have access to collection " || $collection
    )
    else if ($errCollectionPresent instance of xs:string) then
      <rest:response>
        <http:response status="409" />
      </rest:response>
    else 
      let $subCollection := xmldb:create-collection($collection, $collectionData?collectionName)
      
      let $co := xmldb:copy-resource($wdb:edocBaseDB || "/resources", "wdbmeta.xml", $subCollection, "wdbmeta.xml")
      let $newMetaPath := $subCollection || "/wdbmeta.xml"
      
      let $collectionPermissions := sm:get-permissions(xs:anyURI($collection))
      let $metaPermissions := sm:get-permissions(xs:anyURI($collection || "/wdbmeta.xml"))
      
      let $setSubcollPermissions := (
        sm:chown(xs:anyURI($subCollection), $collectionPermissions//@owner || ":" || $collectionPermissions//@group),
        sm:chmod(xs:anyURI($subCollection), $collectionPermissions//@mode)
      )
      let $setMetaPermissions := (
        sm:chown(xs:anyURI($newMetaPath), $metaPermissions//@owner || ":" || $metaPermissions//@group),
        sm:chmod(xs:anyURI($newMetaPath), $metaPermissions//@mode)
      )
      
      let $meta := doc ($newMetaPath)
      
      let $insID := update insert attribute xml:id { $collectionData?id } into $meta/meta:projectMD
      let $insTitle := update value $meta//meta:title[1] with $collectionData?name
      let $insParent := update insert <ptr xmlns="https://github.com/dariok/wdbplus/wdbmeta"
        path="../wdbmeta.xml" /> into $meta/meta:projectMD/meta:struct
      
      let $insPtr := update insert <ptr xmlns="https://github.com/dariok/wdbplus/wdbmeta"
        path="{$collectionData?collectionName}/wdbmeta.xml" xml:id="{$collectionData?id}"
        /> into $parentMeta//meta:files
      let $insStruct := update insert <struct xmlns="https://github.com/dariok/wdbplus/wdbmeta"
        file="{$collectionData?id}" label="{$collectionData?name}"
        /> into $parentMeta/meta:projectMD/meta:struct
      
      return
        <rest:response>
          <http:response status="201">
            <http:header name="x-rest-status" value="{$subCollection}" />
          </http:response>
        </rest:response>
};

(: create a resource in a collection :)
(: create a single file for which no entry has been created in wdbmeta.
   - if a file with the same ID, MIME type and path is found, update it (if these are not a match, return 409)
   - if no target collection is given, return 500
   - if the specified target collection does not exist, return 404
   - if creation is successful, return 201 and the full path where the file was stored :)
declare
  %rest:POST("{$data}")
  %rest:path("/edoc/collection/{$collection}")
  %rest:consumes("multipart/form-data")
  %rest:header-param("Content-Type", "{$header}")
function wdbRc:createFile ($data as xs:string*, $collection as xs:string, $header as xs:string*) {
  try {
    let $user := sm:id()//sm:real/sm:username/string()
    let $err :=
      if ($user = "guest")
        then error (QName("https://github.com/dariok/wdbplus/errors", "wdbErr:h401"))
      else if (not($data) or string-length($data) = 0)
        then error (QName("https://github.com/dariok/wdbplus/errors", "wdbErr:h400"), "no data provided")
      else ()
    
    let $parsed      := wdb:parseMultipart($data, substring-after($header, 'boundary=')),
        $path        := $parsed?1?header?Content-Disposition?filename,
        $contentType := $parsed?1?header?Content-Type
    let $err :=
      if (string-length($path) = 0)
        then error (QName("https://github.com/dariok/wdbplus/errors", "wdbErr:h400"), "no filename provided in form data")
      else if (string-length($contentType) = 0)
        then error (QName("https://github.com/dariok/wdbplus/errors", "wdbErr:h400"), "no Content Type declared for file")
      else ()
      
    let $collectionFile := collection($wdb:data)/id($collection)[self::meta:projectMD]
    let $err := if (not($collectionFile))
      then error (QName("https://github.com/dariok/wdbplus/errors", "wdbErr:h400"), "collection " || $collection || " not found", 404)
      else ()
      
    let $collectionPath := replace($wdb:edocBaseDB  || '/' ||  wdb:getEdPath($collection), "//", "/")
    let $err := if (not(sm:has-access(xs:anyURI($collectionPath), "w")))
      then error (QName("https://github.com/dariok/wdbplus/errors", "wdbErr:h400"), "user " || $user || " has no access to write to collection " || $collectionPath, 403)
      else ()
    
    let $resourceName := xstring:substring-after-last($path, '/'),
        $targetPath   := $collectionPath || '/' || xstring:substring-before-last($path, '/')
    
    (: make sure we really have an ID in the file :)
    let $prepped := wdbRMi:replaceWs($parsed?1?body),
        $contents := if ($contentType = ("text/xml", "application/xml") and not($prepped instance of element() or $prepped instance of document-node()))
          then parse-xml($prepped)
          else $prepped,
        $id := if ($contents instance of document-node())
          then $contents/*[1]/@xml:id
          else ()
    let $err := if ($contents instance of document-node() and not($id))
        then error (QName("https://github.com/dariok/wdbplus/errors", "wdbErr:h400"), "no ID found in XML file")
      else if (collection($wdb:data)/id($id))
        then error (QName("https://github.com/dariok/wdbplus/errors", "wdbErr:h400"), "a file with the ID " || $id || " is already present", 409)
        else ()
    
      (: store $prepped, not $contents as parse-xml() adds prefixes :)
      let $store := wdbRMi:store($targetPath, $resourceName, $prepped, $contentType),
          $meta := if (substring-after($resourceName, '.') = ("xml", "xsl"))
            then wdbRMi:enterMetaXML($store[2])
            else wdbRMi:enterMeta($store[2])
      
      return if ($store[1]//http:response/@status = "200" and $meta[1]//http:response/@status = "200")
        then
          ( 
            <rest:response>
              <http:response status="201">
                <http:header name="Content-Type" value="text/plain" />
                <http:header name="Access-Control-Allow-Origin" value="*" />
                <http:header name="Location" value="{$store[2]}" />
              </http:response>
            </rest:response>,
            $wdb:restURL || "/resource/" || $id
          )
        else if ($store[1]//http:response/@status != "200")
        then $store
        else $meta
  } catch wdbErr:h401 {
    <rest:response>
      <http:response status="401">
        <http:header name="WWW-Authenticate" value="Basic"/>
      </http:response>
    </rest:response>
  } catch * {
    (
      <rest:response>
        <http:response status="{400}">
          <http:header name="Content-Type" value="text/plain" />
          <http:header name="Access-Control-Allow-Origin" value="*"/>
        </http:response>
      </rest:response>,
      $err:description,
      $err:value,
      $err:line-number || ":" || $err:column-number
    )
  }
};

(: list all collections :)
declare
    %rest:GET
    %rest:path("/edoc/collection")
    %rest:header-param("Accept", "{$mt}")
function wdbRc:getCollections ($mt as xs:string*) {
  local:getGeneral ("data", $mt,
    'for $s in $meta//meta:struct[@file] return
      <collection id="{$s/@file}" label="{$s/@label}" />'
  )
};
declare
    %rest:GET
    %rest:path("/edoc/collection.json")
    %rest:produces("application/json")
function wdbRc:getCollectionsJSON () {
  wdbRc:getCollections("application/json")
};
declare
    %rest:GET
    %rest:path("/edoc/collection.xml")
    %rest:produces("application/xml")
function wdbRc:getCollectionsXML () {
  wdbRc:getCollections("application/xml")
};
(: END list all collections :)

(: get a full list of a collection (= subcolls and resources entered into wdbmeta.xml) :)
declare
    %rest:GET
    %rest:path("/edoc/collection/{$id}")
    %rest:header-param("Accept", "{$mt}")
function wdbRc:getCollection ($id as xs:string, $mt as xs:string*) {
  local:getGeneral ($id, $mt,
    '(
      for $s in $meta//meta:struct[@file] return
        <collection id="{$s/@file}" label="{$s/@label}" />,
      for $s in $meta//meta:view return
        <resources id="{$s/@file}" label="{normalize-space($s/@label)}" />)')
};
declare
  %rest:GET
  %rest:path("/edoc/collection/{$id}.xml")
function wdbRc:getCollectionXML ($id) {
  wdbRc:getCollection($id, "application/xml")
};
declare
  %rest:GET
  %rest:path("/edoc/collection/{$id}.json")
  %rest:produces("application/json")
function wdbRc:getCollectionJSON ($id) {
  wdbRc:getCollection($id, "application/json")
};
(: END list a collection :)

(: list resources within a collection (= those entered into wdbmeta.xml) :)
declare
    %rest:GET
    %rest:path("/edoc/collection/{$id}/resources")
    %rest:header-param("Accept", "{$mt}")
function wdbRc:getResources ($id as xs:string, $mt as xs:string*) {
  local:getGeneral ($id, $mt,
    'for $s in $meta//meta:view return
      <resources id="{$s/@file}" label="{normalize-space($s/@label)}" />'
  )
};

declare
  %rest:GET
  %rest:path("/edoc/collection/{$id}/resources.xml")
function wdbRc:getResourcesXML ($id) {
  wdbRc:getResources($id, "application/xml")
};
declare
  %rest:GET
  %rest:path("/edoc/collection/{$id}/resources.json")
  %rest:produces("application/json")
function wdbRc:getResourcesJSON ($id) {
  wdbRc:getResources($id, "application/json")
};
(: END list resources within a collection :)

(: list subcollections of a collection (= those entered into wdbmeta.xml) :)
declare
  %rest:GET
  %rest:path("/edoc/collection/{$id}/collections")
  %rest:header-param("Accept", "{$mt}")
function wdbRc:getSubcoll ( $id as xs:string, $mt as xs:string* ) {
local:getGeneral ($id, $mt,
  'for $s in $meta//meta:struct[@file] return
    <collection id="{$s/@file}" label="{$s/@label}" />'
)
};
declare
  %rest:GET
  %rest:path("/edoc/collection/{$id}/collections.json")
  %output:method("json")
function wdbRc:getSubcollJson ($id) {
  wdbRc:getSubcoll($id, "application/json")
};

declare
  %rest:GET
  %rest:path("/edoc/collection/{$id}/collections.xml")
function wdbRc:getSubcollXML ($id) {
  wdbRc:getSubcoll($id, "application/xml")
};
(: END list subcollections :)

(: get a full list of subcollections in the database (includes those not in
 : wdbmeta.xml – used e.g. to specify a subcollection when uploading :)
declare
  %rest:GET
  %rest:path("/edoc/collection/{$id}/structure.json")
  %output:method("json")
function wdbRc:getStructureJson ( $id ) {
  let $collection-uri := wdb:getEdPath($id, true())
  return map { $collection-uri: xmldb:get-child-collections($collection-uri) }
};

(: navigation :)
declare
    %rest:GET
    %rest:path("/edoc/collection/{$id}/nav.xml")
function wdbRc:getCollectionNavXML ($id as xs:string) {
  let $md := collection($wdb:data)/id($id)[self::meta:projectMD]
  let $uri := base-uri($md)
  let $struct := $md/meta:struct
  
  let $content := <struct xmlns="https://github.com/dariok/wdbplus/wdbmeta" ed="{$id}">{(
      $struct/@*,
      $struct/*
    )}</struct>
  
  return if ($struct/meta:import)
    then local:imported($struct/meta:import, $content)
    else $content
};

declare function local:imported ( $import, $child ) {
  let $uri := base-uri($import)
  let $path := substring-before($uri, "wdbmeta.xml") || $import/@path
  let $meta := doc($path)
  
  let $content := $meta/meta:projectMD/meta:struct
  let $struct := <struct xmlns="https://github.com/dariok/wdbplus/wdbmeta" ed="{$meta/meta:projectMD/@xml:id}">{(
        $content/@*,
        for $st in $content/* return
          if ($st/@file = $child/@ed)
            then $child
            else $st
      )}</struct>
  
  return if ($content/meta:import)
    then local:imported ( $content/meta:import, $struct)
    else $struct
};

declare
    %rest:GET
    %rest:path("/edoc/collection/{$id}/nav.html")
function wdbRc:getCollectionNavHTML ($id as xs:string) {
  let $pathToEd := wdb:getProjectPathFromId($id)
  let $mf := wdb:getMetaFile($pathToEd)
  let $params :=
    <parameters>
      <param name="id" value="{$id}"/>
    </parameters>
  
  let $html := try {
    if(ends-with($mf, 'wdbmeta.xml'))
      then
        let $xsl := if (wdb:findProjectFunction(map {"pathToEd": $pathToEd}, "getNavXSLT", 0))
          then wdb:eval("wdbPF:getNavXSLT()")
          else if (doc-available($pathToEd || '/nav.xsl'))
          then xs:anyURI($pathToEd || '/nav.xsl')
          else xs:anyURI($wdb:edocBaseDB || '/resources/nav.xsl')
        let $struct := wdbRc:getCollectionNavXML($id)
        return transform:transform($struct, doc($xsl), $params)
      else
        transform:transform(doc($mf), doc($pathToEd || '/mets.xsl'), $params)
  } catch * {
    <p>Error transforming meta data file {$mf} to navigation using
      {$pathToEd || '/mets.xsl'}:<br/>{$err:description}</p>
  }
  
  let $status := if ($html[self::*:p]) then '500' else '200'
  
  return (
    <rest:response>
      <http:response status="{$status}">
        <http:header name="Access-Control-Allow-Origin" value="*" />
        <http:header name="Content-Type" value="text/html" />
        <http:header name="REST-Status" value="REST:SUCCESS" />
      </http:response>
    </rest:response>,
    $html
  )
};


declare
  %private
function local:getGeneral ($id, $mt, $content) {
  let $content := if ($mt != $wdbRc:acceptable)
  then
    try {
      let $path := wdb:getProjectPathFromId($id)
      let $meta := doc(wdb:getMetaFile($path))
      
      return if ($meta/*[self::meta:projectMD])
      then
        let $eval := wdb:eval ( $content, false(), (xs:QName("meta"), $meta))
        return if (count($eval) gt 0)
        then (
          200,
          <collection id="{$id}">{
            $eval
          }</collection>
        )
        else ( 204, "" )
      else
        ( 400, "no a wdbmeta project" )
    }
    catch *:wdb0200 {
      ( 404, "no collection with ID " || $id )
    }
    catch * {
      ( 400, "" )
    }
  else (406, string-join($wdbRc:acceptable, '&#x0A;'))
  
  return (
    <rest:response>
      <http:response status="{$content[1]}">
        <http:header name="Content-Type" value="{if ($content[1] = 200) then $mt else 'text/plain'}" />
        {
          if ($content[1] != 200)
          then
            <http:header name="REST-Status" value="{$content[2]}" />
          else ()
        }
        <http:header name="Access-Control-Allow-Origin" value="*"/>
      </http:response>
    </rest:response>,
    if ($content[1] = 200)
      then if ($mt = "application/json")
          then json:xml-to-json($content[2])
          else $content[2]
      else $content[2]
  )
};

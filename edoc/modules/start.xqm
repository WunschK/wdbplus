xquery version "3.0";

module namespace wdbst = "https://github.com/dariok/wdbplus/start";

import module namespace wdb     = "https://github.com/dariok/wdbplus/wdb"	at "app.xql";
import module namespace wdbErr  = "https://github.com/dariok/wdbplus/errors" at "error.xqm";
import module namespace console = "http://exist-db.org/xquery/console";

declare namespace match   = "http://www.w3.org/2005/xpath-functions";
declare namespace mets    = "http://www.loc.gov/METS/";
declare namespace mods    = "http://www.loc.gov/mods/v3";
declare namespace tei     = "http://www.tei-c.org/ns/1.0";
declare namespace output  = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace wdbmeta = "https://github.com/dariok/wdbplus/wdbmeta";
declare namespace wdbPF   = "https://github.com/dariok/wdbplus/projectFiles";

declare option output:method "html5";
declare option output:media-type "text/html";

declare function wdbst:populateModel ($node as node(), $model as map(*), $id, $ed, $path) {
try {
  (: general behaviour: IDs always take precedence :)
  let $ppath := if ($id)
    then wdb:getEdPath(base-uri((collection($wdb:data)/id($id))[self::wdbmeta:projectMD]), true())
    else if ($ed)
    then $wdb:edocBaseDB || '/' || $ed
    else wdb:getEdPath($wdb:edocBaseDB || $path, true())
  
  let $metaFile := if (doc-available($ppath || '/wdbmeta.xml'))
    then doc($ppath || '/wdbmeta.xml')
    else doc($ppath || '/mets.xml')
  
  let $proFile := wdb:findProjectXQM($ppath)
  let $proRes := substring-before($proFile, 'project.xqm') || 'resources/'
  
  let $spec := if ($metaFile/wdbmeta:*)
  then
    let $id := $metaFile//wdbmeta:projectID/text()
    let $title := normalize-space($metaFile//wdbmeta:title[1])
    return map { "id" := $id, "title" := $title, "infoFileLoc" := $ppath || '/wdbmeta.xml' }
  else
    let $id := analyze-string($ppath, '^/?(.*)/([^/]+)$')//match:group[1]/text()
    let $title := normalize-space(($metaFile//mods:title)[1])
    return map { "id" := $id, "title" := $title , "infoFileLoc" := $ppath || '/mets.xml' }
  
  let $base := map { "resources" := $proRes, "ed" := substring-after($ppath, $wdb:data),
    "pathToEd" := $ppath, "fileLoc" := "start.xql" }
  
  return map:merge(($spec, $base))
} catch * {
  wdbErr:error(map { "code" := "wdbErr:wdb3001", "model" := $model, "id" := $id, "ed" := $ed, "path" := $path })
}
};

declare function wdbst:getHead ($node as node(), $model as map(*)) {
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <meta name="id" content="{$model('id')}"/>
    <meta name="edPath" content="{$model('pathToEd')}" />
    <meta name="path" content="{$model('fileLoc')}"/>
    <title>{normalize-space($wdb:configFile//*:short)} – {$model("title")}</title>
    <link rel="stylesheet" type="text/css" href="{$wdb:edocBaseURL}/resources/css/start.css" />
    {
      if (util:binary-doc-available($model("resources") || 'projectStart.css'))
      then <link rel="stylesheet" type="text/css" href="{$wdb:edocBaseURL}{substring-after($model("resources"), $wdb:edocBaseDB)}projectStart.css" />
      else()
    }
    <script src="{$wdb:edocBaseURL}/resources/scripts/function.js" />
    {
      if (util:binary-doc-available($model("resources") || 'projectStart.js'))
      then <script src="{$wdb:edocBaseURL}{substring-after($model("resources"), $wdb:edocBaseDB)}projectStart.js" />
      else()
    }
  </head>
};

declare function wdbst:getStartHeader($node as node(), $model as map(*)) as node()* {
  if (doc-available($model("resources") || 'startHeader.html'))
  then doc($model("resources") || 'startHeader.html')
  else if (wdb:findProjectFunction($model, 'getStartHeader', 1))
  then wdb:eval('wdbPF:getStartHeader($model)', false(), (xs:QName('model'), $model))
  else (
    <h1>{$model("title")}</h1>,
    <hr/>
  )
};

declare function wdbst:getStartLeft($node as node(), $model as map(*)) as node()* {
  if (doc-available($model("resources") || 'startLeft.html'))
  then doc($model("resources") || 'startLeft.html')
  else if (wdb:findProjectFunction($model, 'getStartLeft', 1))
  then wdb:eval('wdbPF:getStartLeft($model)', false(), (xs:QName('model'), $model))
  else (<h1>Inhalt</h1>,())
};

declare function wdbst:getStart ($node as node(), $model as map(*)) as node()* {
  if (doc-available($model("resources") || 'startRight.html'))
  then doc($model("resources") || 'startRight.html')
  else if (wdb:findProjectFunction($model, 'getStart', 1))
  then wdb:eval('wdbPF:getStart($model)', false(), (xs:QName('model'), $model))
  else local:getRight($model)
};

declare function local:getRight($model as map(*)) {
	let $xml := concat($model("pathToEd"), '/start.xml')
	
	let $xsl := if (doc-available(concat($model("ed"), '/start.xsl')))
		then $model("pathToEd") || '/start.xsl'
		else $wdb:edocBaseDB || '/resources/start.xsl'
	
	return
		<div class="start">
			{transform:transform(doc($xml), doc($xsl), ())}
			{wdb:getFooter($xml, $xsl)}
		</div>
};
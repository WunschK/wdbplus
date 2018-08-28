(: kontrolliert die Verarbeitung von projektspezifischen XQuery;
 : Bearbeiter:DK Dario Kampkaspar
 : erstellt 2016-11-03 DK :)
xquery version "3.0";

module namespace wdbpq = "https://github.com/dariok/wdbplus/pquery";

import module namespace templates	= "http://exist-db.org/xquery/templates" ;
import module namespace wdb			= "https://github.com/dariok/wdbplus/wdb" at "app.xql";
import module namespace console 	= "http://exist-db.org/xquery/console";
import module namespace wdba		= "https://github.com/dariok/wdbplus/auth" at "auth.xqm";

declare namespace meta	= "https://github.com/dariok/wdbplus/wdbmeta";

declare %templates:default("q", "") %templates:default("q2", "") %templates:default("query", "") %templates:default("ed", "")
    %templates:default("global", "")
	function wdbpq:start($node as node(), $model as map(*), $ed as xs:string, $query as xs:string, $q as xs:string,
		$q2 as xs:string, $global as xs:string) as map(*) {
	
	let $edPath := if ($ed = "")
	    then ""
	    else wdb:getEdPath($ed, true())
	
	let $metaFile := doc($edPath||'/wdbmeta.xml')
	let $title := $metaFile//meta:title/text()
	
	return map{ "query" := $query, "q" := $q, "q2" := $q2, "ed" := $ed, "edPath" := $edPath, "title" := $title, "global" := $global }
};

(: die angegebene Datei laden. Die Eingangsfunktion muß gegeben sein; 2016-11-03 DK :)
(: TODO geht das auch anders? :)
(: Wir nehmen grundsätzlich an, daß die Skripte im Unterverzeichnis scripts innerhalb des Projektordners liegen
		(vgl. Mail Thomas 2017-01-04T12:05) :)
declare function wdbpq:body($node as node(), $model as map(*)) {
	let $path := $model("edPath")  || '/' || $model("query")
	let $module := util:import-module(xs:anyURI("https://github.com/dariok/wdbplus/wdbq"), 'wdbq', xs:anyURI($path))
	
	return util:eval("wdbq:query($map)", xs:boolean('false'), (xs:QName('map'), $model))
};

(: gibt das h2 für die navbar aus; neu 2017-03-27 DK :)
declare function wdbpq:getTask($node as node(), $model as map(*)) {
	let $path := $model("edPath")  || '/' || $model("query")
	let $module := util:import-module(xs:anyURI("https://github.com/dariok/wdbplus/wdbq"), 'wdbq', xs:anyURI($path))
	
	return util:eval("wdbq:getTask()", xs:boolean('false'), (xs:QName('map'), $model))
};

(:~
 : return the header
 :)
declare function wdbpq:getHeader ( $node as node(), $model as map(*) ) {
    <header>
    	<h1>{$model("title")}</h1>
    	{wdba:getAuth($node, $model)}
    	<span class="dispOpts">[<a id="showNavLink" href="javascript:toggleNavigation();">Navigation
				einblenden</a>]</span>
    	<hr/>
    	<nav style="display:none;" />
    </header>
};

(:~
 : return html:meta to identify the project
 :)
declare function wdbpq:getEd ($node as node(), $model as map(*)) {
	<meta name="id" content="{$model('ed')}"/>
};

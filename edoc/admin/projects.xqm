xquery version "3.0";

module namespace wdbPL = "https://github.com/dariok/wdbplus/ProjectList";

import module namespace console  = "http://exist-db.org/xquery/console";
import module namespace sm       = "http://exist-db.org/xquery/securitymanager";
import module namespace wdb      = "https://github.com/dariok/wdbplus/wdb"    at "../modules/app.xqm";
import module namespace wdbs     = "https://github.com/dariok/wdbplus/stats"  at "../modules/stats.xqm";
import module namespace xstring  = "https://github.com/dariok/XStringUtils"   at "../include/xstring/string-pack.xql";

declare namespace config = "https://github.com/dariok/wdbplus/config";
declare namespace meta   = "https://github.com/dariok/wdbplus/wdbmeta";
declare namespace tei    = "http://www.tei-c.org/ns/1.0";

declare function wdbPL:pageTitle ($node as node(), $model as map(*)) {
  let $t := $wdb:configFile//config:short
  
  return <title>{normalize-space($t)} – Admin</title>
};

declare function wdbPL:body ( $node as node(), $model as map(*) ) {
  let $file := request:get-parameter('file', '')
  let $job := request:get-parameter('job', '')
  let $user := sm:id()
  
  return
    if (not($user//sm:group = 'dba'))
      then <p>Diese Seite ist nur für Administratoren zugänglich!</p>
    else if ($job != '') then
      let $editionID := $model?id
      let $metaPath := $model?infoFileLoc
      let $metaFile := doc($metaPath)
      
      let $relativePath := substring-after($file, $model?pathToEd || '/')
      let $subColl := xstring:substring-before-last($file, '/')
      let $resource := xstring:substring-after-last($file, '/')
      let $fileEntry := $metaFile//meta:file[@path = $relativePath]
      let $xml := doc($file)
      
      return switch ($job)
        case 'add' return
          let $ins := <file xmlns="https://github.com/dariok/wdbplus/wdbmeta" path="{$relativePath}" uuid="{util:uuid($xml)}" 
            date="{xmldb:last-modified(xstring:substring-before-last($file, '/'), xstring:substring-after-last($file, '/'))}"
            xml:id="{$xml/tei:TEI/@xml:id}" />
          let $up1 := update insert $ins into $metaFile//meta:files
          return local:getFileStat($model , $file)
        
        case 'uuid' return
          let $ins := attribute uuid {util:uuid($xml)}
          let $up1 := if ($fileEntry/@uuid)
            then update replace $fileEntry/@uuid with $ins
            else update insert $ins into $fileEntry
          return local:getFileStat($model, $file)
        
        case 'pid' return
          let $ins := attribute pid { string($xml//tei:publicationStmt/tei:idno[@type = 'URI']) }
          let $up1 := if ($fileEntry/@pid)
            then update replace $fileEntry/@pid with $ins
            else update insert $ins into $fileEntry
          return local:getFileStat($model, $file)
        
        case 'date' return
          let $ins := attribute date {xmldb:last-modified($subColl, $resource)}
          let $up1 := if ($fileEntry/@date)
            then update replace $fileEntry/@date with $ins
            else update insert $ins into $fileEntry
          return local:getFileStat($model, $file)
        
        case 'id' return
          let $ins := attribute xml:id {normalize-space($xml/tei:TEI/@xml:id)}
          let $upd1 := if ($fileEntry/@xml:id)
            then update replace $fileEntry/@xml:id with $ins
            else update insert $ins/@xml:id into $fileEntry
          return local:getFileStat($model, $file)
        
        case 'private' return
          let $id := normalize-space($xml/tei:TEI/@xml:id)
          let $view := ($metaFile//meta:view[@file = $id])[1]
          let $upd := if ($view/@private = 'true')
            then update value $view/@private with 'false'
            else if ($view/@private = 'false')
              then update value $view/@private with 'true'
              else update insert attribute private {'true'} into $view
          return local:getFileStat($model, $file)
        
        default return
          <div id="data"><div><h3>Strange Error</h3></div></div>
    (: no job given :)
    else if (($model?ed = 'data' or $model?ed = '') and $file = '') then
      <div id="content">
        <h3>Liste der Projekte</h3>
        {wdbs:projectList(true(), '')}
      </div>
    else if ($model?ed != 'data' and $model?ed != ''and $file = '') then
      local:getFiles($model)
    else
      local:getFileStat($model, $file)
};

declare function local:getFiles($model) {
  let $filesInEd := collection($model?pathToEd)//tei:TEI
  return 
    <div id="content">
      <h1>Insgesamt {count($filesInEd)} Texte</h1>
      {
        if (not(doc-available($model?infoFileLoc)))
          then <p>keine <code>wdbmeta.xml</code> vorhanden!</p>
          else ()
      }
      <table class="noborder">
        <tbody>
          <tr>
            <th>Nr.</th>
            <th>Pfad</th>
            <th>Titel</th>
            <th>Status</th>
          </tr>
          {
            for $doc in $filesInEd
              let $docUri := base-uri($doc)
              return
                <tr>
                  <td>{$doc/@n}</td>
                  <td>{$docUri}</td>
                  <td>
                    <a href="../view.html?id={$doc/@xml:id}">
                      {substring(string-join($doc//tei:titleStmt/*, ' - '), 1, 100)}
                    </a>
                  </td>
                  <td><a href="javascript:show('{$model?ed}', '{$docUri}')">anzeigen</a></td>
                </tr>
          }
        </tbody>
      </table>
    </div>
};

declare function local:getFileStat($ed, $file) {
  let $doc := doc($file)
  let $subColl := xstring:substring-before-last($file, '/')
  let $resource := xstring:substring-after-last($file, '/')
  let $metaPath := $wdb:edocBaseDB || '/' || $ed || '/wdbmeta.xml'
  let $metaFile := doc($metaPath)
  let $relativePath := substring-after($file, $ed||'/')
  let $entry := $metaFile//meta:file[@path = $relativePath]
  let $uuid := util:uuid($doc)
  let $pid := $doc//tei:titleStmt/tei:idno[@type = 'URI']
  let $date := xmldb:last-modified($subColl, $resource)
  let $id := normalize-space($doc/tei:TEI/@xml:id)
  
  return
    <div id="data">
      <div style="width: 100%;">
        <h3>{$file}</h3>
        <hr />
        <table style="width: 100%;">
          <tbody>
            {
              for $title in $doc//tei:teiHeader/tei:title
                return <tr><td>Titel</td><td>{$title}</td></tr>
            }
            <tr>
              <td>UUID v3</td>
              <td>{$uuid}</td>
            </tr>
            <tr>
              <td>externe PID</td>
              <td>{$pid}</td>
            </tr>
            <tr>
              <td>Timestamp</td>
              <td>{$date}</td>
            </tr>
            <tr>
              <td>Metadaten-Datei</td>
              <td>{$metaPath}</td>
            </tr>
            <tr>
              <td>relativer Pfad zur Datei</td>
              <td>{$relativePath}</td>
            </tr>
            <tr>
              <td>Eintrag in <i>wdbmeta.xml</i> vorhanden?</td>
              {if ($entry/@path != '')
                then <td>OK</td>
                else <td>fehlt <a href="javascript:job('add', '{$file}')">hinzufügen</a></td>
              }
            </tr>
            {if ($entry/@path != '')
              then (
                <tr>
                  <td style="border-top: 1px solid black;">UUID in wdbMeta</td>
                  {if ($entry/@uuid = $uuid)
                    then <td>OK: {$uuid}</td>
                    else <td>{normalize-space($entry/@uuid)}<br/><a href="javascript:job('uuid', '{$file}')">UUID aktualisieren</a></td>
                  }
                </tr>,
                <tr>
                  <td>externe PID</td>
                  <td>{if ($entry/@pid = $pid)
                    then "OK: " || string($entry/@pid)
                    else <a href="javascript:job('pid', '{$file}'">PID aus Datei übernehmen</a>
                  }</td>
                </tr>,
                <tr>
                  <td>Timestamp in wdbMeta</td>
                  {if ($entry/@date = $date)
                    then <td>OK: {$date}</td>
                    else <td>{normalize-space($entry/@date)}<br/><a href="javascript:job('date', '{$file}')">Timestamp aktualisieren</a></td>
                  }
                </tr>,
                <tr>
                  <td><code>@xml:id</code> in wdbMeta</td>
                  {if ($entry/@xml:id = $id)
                    then <td>OK: {$id}</td>
                    else <td>{normalize-space($entry/@xml:id)}<br/><a href="javascript:job('id', '{$file}')">ID aktualisieren</a></td>
                  }
                </tr>
              )
              else ()
            }
          </tbody>
        </table>
        {
          if ($wdb:role = 'workbench') then
            let $remoteMetaFile := try {
               doc($wdb:peer || '/' || $ed || '/wdbmeta.xml')
            } catch * {
              console:log("Peer meta file not found: " || $wdb:peer || '/' || $ed || '/wdbmeta.xml --' ||
                'e: ' ||  $err:code || ': ' || $err:description || ' @ ' || $err:line-number ||':'||$err:column-number || '
                c: ' || $err:value || ' in ' || $err:module || '
                a: ' || $err:additional)
            }
            let $remoteEntry := $remoteMetaFile//meta:file[@path = $relativePath]
            
            return (
              <h3>Peer Info</h3>,
              <table style="width: 100%;">
                <tbody>
                  <tr>
                    <td>Peer Server</td>
                    <td>{$wdb:peer}</td>
                  </tr>
                  <tr>
                    <td>Eintrag in <i>wdbmeta.xml</i> vorhanden?</td>
                    {if ($remoteEntry/@path != '')
                      then <td>OK</td>
                      else <td>fehlt</td>
                    }
                  </tr>
                  {if ($remoteEntry/@path != '')
                    then (
                      <tr>
                        <td>UUID in wdbMeta</td>
                        {if ($remoteEntry/@uuid = $uuid)
                          then <td>OK: {$uuid}</td>
                          else <td>Diff: {normalize-space($remoteEntry/@uuid)}</td>
                        }
                      </tr>,
                      <tr>
                        <td>Timestamp in wdbMeta</td>
                        {if ($remoteEntry/@date = $date)
                          then <td>OK: {$date}</td>
                          else <td>Diff: {normalize-space($remoteEntry/@date)}</td>
                        }
                      </tr>,
                      <tr>
                        <td><code>@xml:id</code> in wdbMeta</td>
                        {if ($remoteEntry/@xml:id = $id)
                          then <td>OK: {$id}</td>
                          else <td>Diff: {normalize-space($remoteEntry/@xml:id)}</td>
                        }
                      </tr>
                    )
                    else ()
                  }
                </tbody>
              </table>
            )
          else ()
        }
        {
          if ($wdb:role = 'standalone') then
            let $status := if ($metaFile//meta:view[@file = $id])
              then
                let $view := ($metaFile//meta:view[@file = $id])[1]
                return if ($view/@private = true())
                  then 'intern'
                  else 'sichtbar'
              else 'Kein Struktureintrag'
            return (
              <h3>Verwaltung</h3>,
              <table>
                <tbody>
                  <tr>
                    <td>Status</td>
                    <td>{
                      if ($status = 'Kein Struktureintrag') then
                        $status
                      else
                        let $link := <a href="javascript:job('private', '{$file}')">umschalten</a>
                        return ($status, <br/>, $link)
                    }</td>
                  </tr>
                </tbody>
              </table>
            )
          else ()
        }
      </div>
    </div>
};
/* globals wdb */
/* jshint browser: true */

const wdbAdmin = {
  displayRight: function ( url ) {
    $.ajax({
      method: "get",
      url: url,
      cache: false,
      success: function ( data ) {
        let result = $('<div/>').append( data ).find( '#data' ).html(); 
        $( '#rightSide' ).html( result ); 
      }
    });
  },

  // show info for a file
  showFile: function ( ed, file ) {
    let url = 'projects.html?ed=' + ed + '&file=' + file;
    this.displayRight(url);
  },

  // execute a job and show results
  showJob: function ( job, file ) {
    let url = 'projects.html?job=' + job + '&file=' + file;
    this.displayRight ( url );
  },

  /* check files in the upload list and prompt upload if everything is okay */
  prepareForUpload: async function (file, i, fileid, headers) {
    if (fileid !== "undefined" && fileid !== 0) {
      let task = $('#selectTask input:checked').attr("id"),
          item = $('#results').children()[i],
          text = (task == "fi") ? file.name : item.innerText,
          collection = $('#selectTarget select').val() !== undefined ?
              $('#selectTarget select').val() :
              wdb.parameters.collection,
          delimiter = (wdb.meta.rest.substr(wdb.meta.rest.length - 1)) == '/' ? "" : "/",
          pathToEd = $('#selectTarget').find('option')[0].innerHTML,
          edRoot = pathToEd.substr(pathToEd.lastIndexOf('/') + 1),
          relativeFilePath = task == "fi" ?
              collection.substr(pathToEd.length + 1) + '/' + text :
              text.substr(0, edRoot.length) == edRoot ?
                  text.substr(edRoot.length + 1) :
                  collection.substr(collection.indexOf('/' + edRoot) + edRoot.length + 1) + '/' + text,
          mdMode = task == "do" ? "" : "?meta=1";
      
      console.info("checking fileid: " + fileid);
    
      let formdata = new FormData();
      formdata.append("file", file)
        .append("filename", relativeFilePath)
        .append("targetCollection", collection);
      
      let collectionContent;
      $.ajax({
        method: "get",
        url: wdb.meta.rest + delimiter + "collection/" + collection,
        success: function ( data ) {
          collectionContent = data;
        },
        error: function ( response ) {
          console.error("error getting contents of collection " + collection + ":\n" + response);
          return false;
        }
      });
      
      try {
        if (collectionContent.hasOwnProperty(fileid)) {
          $(item).children("span")[0].innerText = "…";
          doUpload("put", wdb.meta.rest + delimiter + "resource/" + fileid + mdMode, headers, formdata, item, text);
        } else {
          $(item).children("span")[0].innerText = "…";
          doUpload("post", wdb.meta.rest + delimiter + "collection/" + wdb.parameters.ed + mdMode, headers, formdata, item, text);
        }
      } catch (e) {
        console.error(e);
        $(item).children("span").innerText = "✕";
      }
    }
  }
};
Object.freeze(wdbAdmin);

/* event listeners */
$('#picker').on("submit", dirupload);

$(document).on("change", "#picker", function() {
  $('#results').children().remove();
  
  let files = this.files;
  
  for (let file of files) {
    let task = $('#selectTask input:checked').attr("id"),
        filePath = task == "fi" ? file.name : file.webkitRelativePath;
    
    $('#results').append("<li>" + filePath + "<span></span></li>");
  }
});



$("document").ready(function() {
  if (params['id'] !== undefined)
  {
    let delim = (rest.substr(rest.length - 1)) == '/' ? "" : "/";
    let url = rest + delim + "collection/" + params["id"] + "/collections.json";
    $.ajax({
      method: "get",
      url: url,
      success: function (data) {
        getPaths(data);
        $("input[type='submit']").prop("disabled", false);
        $("aside").html("");
      },
      error: function (response) {
        console.log(response);
        $("aside").html("<p>Kein Projekt mit der ID " + params["id"] + " gefunden oder Projekt für den aktuellen Benutzer nicht lesbar.</p>");
      }
    });
    $('#selectTarget').show();
  }
});
function getPaths (data) {
  if (data.hasOwnProperty("path"))
    $('#selectTarget select').append("<option>" + data["path"] + "</option>");
  if (data.hasOwnProperty("collection"))
    if (data.collection instanceof Array) data["collection"].forEach(function(coll) { getPaths(coll); });
    else $('#selectTarget select').append("<option>" + data.collection["path"] + "</option>");
}







async function doUpload(method, url, headers, formdata, item, text) {
  $.ajax({
    method: method,
    url: url,
    headers: headers,
    data: formdata,
    contentType: false,
    processData: false,
    success: function (response, textStatus, xhr) {
      $(item).children("span")[0].innerText = "✓";
      $(item).append('<span class="success">' + textStatus + '</span>');
    },
    error: function (response) {
      $(item).children("span")[0].innerText = "✕";
      $(item).append('<span class="error">Error: ' + response.status + "</span>");
    }
  });
}

function dirupload (event) {
  event.preventDefault();
  $('p img').show();
  
  let cred = Cookies.get("wdbplus");
  let headers = (typeof cred !== "undefined" && cred.length != 0)
    ? {"Authorization": "Basic " + cred}
    : "";
  
  for (let i = 0; i < files.length; i++) {
    let file = files[i],
        item = $('#results').children()[i],
        text = item.innerText;
    console.log("processing " + file.name);
    
    let reader = new FileReader();
    reader.onload = function(readFile) {
      $(item).children("span").innerText = "…";
      let content = readFile.target.result,
          fileid = 0;
      try {
        let parsed = $.parseXML(content.substring(content.indexOf("<TEI")));
        let xml = $(parsed);
        fileid = xml.find("TEI").attr("xml:id");
      } catch (e) {
        console.log("error parsing XML from " + file.name);
        console.log(e);
        item.innerText = text.substring(0, text.length) + "✕ Parser Error ";
      }
      
      if (fileid !== undefined && fileid !== 0) {
        console.log("parsed file’s ID: " + fileid);
        sendData(file, i, fileid, headers);
      } else {
        console.log("no @xml:id found in " + file.name);
        item.innerText = text.substring(0, text.length) + "✕ No xml:id found ";
      }
    };
    reader.readAsText(file, "UTF-8");
  }
  
  $('p img').hide();
}

function ingestAction(event) {
  if(event.target.id == "fi") {
    $('#picker').attr('webkitdirectory', null);
    $('#selectInputDir label').text("Datei auswählen");
  }
  else {
    $('#picker').attr('webkitdirectory', 'true');
    $('#selectInputDir label').text("Verzeichnis auswählen");
  }
}


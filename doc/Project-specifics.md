# Project specifics

While this app aims at making available many default scripts so that any project can start by just uploading XML files, most projects will want to add some specific scripts or change the layout.
In order to achieve this without affecting other projects, this app provides several levels of customization.
Global scripts should remain unchanged.<sup id="a1">[1](#f1)</sup>
By default, the template loads global CSS files (namely, `wdb.css` and either `view.css` for `view.html` or
`function.csss` for other pages) and the global `function.js`.
These provide the basic layout and functionality of the app. An overview of what is defined globally can be found in [[the list of CSS files and classes|css-files-and-classes]] and [[the list of JS functions|js-functions]]

## Simple extension: `project.css` and `project.js`
If your needs for adaptation are not too complex or you have some changes that you need for all files in a project,
each project (i. e. any collection with an own `project.xqm`) can have customized CSS and JS files. A file called
`project.css` or `project.js`, respectively, located in `{$project}/resources` will be loaded automatically _after_ the
global scripts (`wdb.css`, `view.css`/`function.css`, or `function.js`) – this means you can simply override any style
or function definition given globally. Keep in mind, though, that if you override any of these, especially the
JavaScript functions, you are responsible to implement their functionality yourself should you want to keep
it.<sup id="a2">[2](#f2)</sup>

## Complex extensions
If the selection of a CSS or JS is more complex than the method above, for example if you need different stylesheets for
introductions and transcriptions, you can select these by means of an XQuery function in [[project.xqm]]. The files
loaded by this method will be loaded last, meaning you can override any definition you made in `project.css` or
`project.js`.

This mechanism should give you sufficient freedom to adapt the layout of any project to the specific needs.

## Queries with templating
In order to easily use templating with any XQuery within a project, queries can be called via `query.html`. Such an
XQuery script MUST be a module in [[namespace `wdbq`|list-of-namespaces]] and implement a function
`wdbq:query($map as map(*))` and SHOULD implement `wdbq:getTask()`.

!! UPDATE !!
The URL should look like this: `query.html?ed={$pathToEd}&query={$pathToQueryWithinProject}&q={$firstParameter}&q2={$secondParameter}`.
Parameters `q` and `q2` can be accessed via `$model` by `wdbq:query($model)`.

---

1. <a id="f1" />While it is possible to adapt the global XSLT, CSS and JavaScript files – e. g. to make sure all
projects use the same layout –, you should keep in mind that these may be replaced during an update or upgrade. If you
make changes, be sure to save them to a location outside of `{$approot}/resources`. [↩](#a1)
1. <a id="f2" />This means that if, for instance, you want to change the function to display footnotes, you have to
implement all the steps necessary. JavaScript does not work in a cascading way as does CSS. [↩](#a2)
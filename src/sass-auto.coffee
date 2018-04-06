path = require 'path'

sass = require 'node-sass'
resolve = require 'resolve'

convention = require './'
util = require './util'


module.exports = (app) ->
    app.styleExtensions.push '.sass'
    app.styleExtensions.push '.scss'

    resolveOpts =
        paths: module.constructor.globalPaths
        extensions: extensions = ['.sass', '.scss', '.css']
        packageFilter: (p) ->
            for e in extensions
                return p if p.main?.endsWith e
            delete p.main

    app.compilers['.scss'] = app.compilers['.sass'] = (file, filename, options) ->
        options ||= {}
        for resource in convention.resources.style
            file += '\n'
            ancestor = resource
            while ancestor = ancestor.parent
                continue unless ancestor.type == 'pages'
                file += "body.#{ancestor.fullName.replace /:/g, '-'}\n  "
                break
            file += "@import '#{resource.requirePath}'\n"

        result = sass.renderSync
            data: file
            indentedSyntax: path.extname(filename) == '.sass'
            includePaths: [path.dirname filename]
            outputStyle: 'compressed'
            importer: (url, prev) ->
                try
                    basedir =
                        if prev == 'stdin'
                            path.dirname require.main.filename
                        else
                            path.dirname prev
                    filePath = resolve.sync url,
                        Object.assign basedir: basedir, resolveOpts
                    pathParse = path.parse filePath
                    if pathParse.ext == '.css'
                        # Если указать путь с расширением, @import будет передаваться на клиента,
                        # а не подключать файл на сервере. Можно было бы в таком виде отдавать все пути,
                        # но тогда в node-sass возникает конфликт при наличии нескольких файлов с разным расширением.
                        filePath = path.join pathParse.dir, pathParse.name
                    file: filePath
                catch e
                    throw e unless e.message?.startsWith 'Cannot find module'

        css: result.css.toString()
        files: result.stats.includedFiles

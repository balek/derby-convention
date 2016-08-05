path = require 'path'

sass = require 'node-sass'
_ = require 'lodash'
resolve = require 'resolve'

util = require './util'


module.exports = (app) ->
    app.styleExtensions.push '.sass'
    app.styleExtensions.push '.scss'

    resolveOpts =
        extensions: extensions = ['.sass', '.scss', '.css']
        packageFilter: (p) ->
            for e in extensions
                return pkg if p.main?.endsWith e
            delete p.main

    app.compilers['.scss'] = app.compilers['.sass'] = (file, filename, options) ->
        options ||= {}
        for name in app.components
            try
                resolve.sync name, resolveOpts
                file += "\n@import '#{name}'\n"
        for moduleName, moduleContents of app.modules
            try
                resolve.sync moduleName, resolveOpts
                file += "\nbody.#{moduleName}\n  @import '#{moduleName}'\n"
            for name in moduleContents.components
                try
                    resolve.sync moduleName + '/components/' + name, resolveOpts
                    file += "\n@import '#{moduleName}/components/#{name}'\n"
            for name in moduleContents.pages
                try
                    resolve.sync moduleName + '/pages/' + name, resolveOpts
                    file += "\nbody.#{moduleName}-pages-#{name}\n  @import '#{moduleName}/pages/#{name}'\n"

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
                        _.extend resolveOpts, basedir: basedir
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

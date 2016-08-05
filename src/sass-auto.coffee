sass = require 'node-sass'
path = require 'path'
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
                compPath = resolve.sync name, resolveOpts
                file += "\n@import '#{compPath}'\n"
        for moduleName, moduleContents of app.modules
            try
                compPath = resolve.sync moduleName, resolveOpts
                file += "\nbody.#{moduleName}\n  @import '#{compPath}'\n"
            for name in moduleContents.components
                try
                    compPath = resolve.sync moduleName + '/components/' + name, resolveOpts
                    file += "\n@import '#{compPath}'\n"
            for name in moduleContents.pages
                try
                    ctrlPath = resolve.sync moduleName + '/pages/' + name, resolveOpts
                    file += "\nbody.#{moduleName}-pages-#{name}\n  @import '#{ctrlPath}'\n"

        result = sass.renderSync
            data: file
            indentedSyntax: path.extname(filename) == '.sass'
            includePaths: [path.dirname filename]
            outputStyle: 'compressed'
            importer: (url, prev) ->
                try
                    filePath = resolve.sync url,
                        basedir: path.dirname prev
                        extensions: ['.sass', '.scss', '.css']
                        packageFilter: (p) -> delete p.main
                    pathParse = path.parse filePath
                    if pathParse.ext == '.css'
                        # Если указать путь с расширением, @import будет передаваться на клиента,
                        # а не подключать файл на сервере. Можно было бы в таком виде отдавать все пути,
                        # но тогда в node-sass возникает конфликт при наличии нескольких файлов с разным расширением.
                        filePath = path.join pathParse.dir, pathParse.name
                    file: filePath

        css: result.css.toString()
        files: result.stats.includedFiles

path = require 'path'

_ = require 'lodash'
resolve = require 'resolve'
derby = require 'derby'

util = require './util'


derby.use require '../subcomponents'

module.exports = (app, options) ->
    app.use require 'derby-controller'
    app.serverUse module, './sass-auto'

    dirname = path.dirname app.filename
    if derby.util.isServer
        fs = derby.util.serverRequire module, 'fs'

        app.on 'bundle', (bundler) ->
            bundler.require _.flatMapDeep app.modules, (moduleContents, moduleName) -> [
                    if moduleContents.index then moduleName else []
                    if moduleContents.opts then moduleName + '/opts'
                    _.map moduleContents.components, (p) -> if moduleName then moduleName + '/components/' + p else 'components/' + p
                    _.map moduleContents.pages, (p) -> if moduleName then moduleName + '/pages/' + p else 'pages/' + p
                    _.map moduleContents.model, (p) -> if moduleName then moduleName + '/model/' + p else 'model/' + p
                ]
            bundler.require app.components

            bundler.exclude 'app-modules'
            a = new require('stream').Readable()
            a.push 'module.exports = ' + JSON.stringify app.modules
            a.push null
            bundler.require a, expose: 'app-modules'


        app.components = options.components
        app.modules = {}
        for moduleInfo in options.modules
            if _.isString moduleInfo
                moduleInfo = name: moduleInfo
            moduleContents = app.modules[moduleInfo.name] =
                path:
                    if moduleInfo.name
                        resolve.sync moduleInfo.name, isFile: util.isDirectory
                    else
                        dirname
                url: moduleInfo.url ? '/' + moduleInfo.name
                components: []
                pages: []
                model: []

            try
                require.resolve moduleInfo.name
                moduleContents.index = true
            catch e
                throw e unless e.code == 'MODULE_NOT_FOUND'

            try
                if moduleInfo.name
                    require.resolve moduleInfo.name + '/opts'
                    moduleContents.opts = true
            catch e
                throw e unless e.code == 'MODULE_NOT_FOUND'
                
            componentsPath = path.join moduleContents.path, 'components'
            if fs.existsSync componentsPath
                for name in fs.readdirSync componentsPath
                    compPath = path.join componentsPath, name
                    if fs.statSync(compPath).isDirectory()
                        moduleContents.components.push name

            pagesPath = path.join moduleContents.path, 'pages'
            if fs.existsSync pagesPath
                for name in fs.readdirSync pagesPath
                    ctrlPath = path.join pagesPath, name
                    if fs.statSync(ctrlPath).isDirectory()
                        moduleContents.pages.push name

            modelPath = path.join moduleContents.path, 'model'
            if fs.existsSync modelPath
                for name in fs.readdirSync modelPath
                    name = path.parse(name).name
                    moduleContents.model.push name

    else
        app.modules = require 'app-modules'


    for name in options.components or []
        app.component require name

    for moduleName, moduleContents of app.modules
        require moduleName if moduleContents.index

        if moduleContents.opts
            opts = require moduleName + '/opts'
            _.extend opts, moduleContents

        for name in moduleContents.components
            compPath = path.join moduleContents.path, 'components', name
            if moduleName
                comp = require moduleName + '/components/' + name
                comp::name = moduleName + ':' + name
            else
                comp = require 'components/' + name
            comp::view = compPath
            app.component comp

        for name in moduleContents.pages
            ctrlPath = path.join moduleContents.path, 'pages', name
            if moduleName
                ctrl = require moduleName + '/pages/' + name
                ctrl::name = moduleName + ':pages:' + name
            else
                ctrl = require 'pages/' + name
                ctrl::name = 'pages:' + name
            ctrl::view = ctrlPath
            if _.isString ctrl::path
                ctrl::path = moduleContents.url + ctrl::path
            else
                ctrl::path =
                    for path in ctrl::path
                        moduleContents.url + ctrl::path
                    
            app.controller ctrl
        for name in moduleContents.model
            app.proto[_.capitalize name] = require moduleName + '/model/' + name
            
            
            
    app.loadStyles dirname + '/styles'
    app.loadViews dirname + '/views'

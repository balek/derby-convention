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
            bundler.require _.flatMapDeep app.modules, (moduleInfo, moduleName) -> [
                    if moduleInfo.index then moduleName else []
                    if moduleInfo.opts then moduleName + '/opts' else []
                    _.map moduleInfo.components, (p) -> if moduleName then moduleName + '/components/' + p else 'components/' + p
                    _.map moduleInfo.pages, (p) -> if moduleName then moduleName + '/pages/' + p else 'pages/' + p
                    _.map moduleInfo.model, (p) -> if moduleName then moduleName + '/model/' + p else 'model/' + p
                ]
            bundler.require app.components or []

            bundler.exclude 'app-modules'
            a = new require('stream').Readable()
            a.push 'module.exports = ' + JSON.stringify app.modules
            a.push null
            bundler.require a, expose: 'app-modules'


        app.components = options.components
        app.modules = {}
        globalPaths = module.constructor.globalPaths
        for moduleInfo in options.modules
            if _.isString moduleInfo
                moduleInfo = name: moduleInfo
            app.modules[moduleInfo.name] = _.defaults moduleInfo,
                path:
                    if moduleInfo.name
                        resolve.sync moduleInfo.name,
                            isFile: util.isDirectory
                            paths: globalPaths
                    else
                        dirname
                url: '/' + moduleInfo.name
                components: []
                pages: []
                model: []

            try
                require.resolve moduleInfo.name,
                    paths: globalPaths
                moduleInfo.index = true
            catch e
                throw e unless e.code == 'MODULE_NOT_FOUND'

            try
                if moduleInfo.name
                    require.resolve moduleInfo.name + '/opts',
                        paths: globalPaths
                    moduleInfo.opts = true
            catch e
                throw e unless e.code == 'MODULE_NOT_FOUND'
                
            componentsPath = path.join moduleInfo.path, 'components'
            if fs.existsSync componentsPath
                for name in fs.readdirSync componentsPath
                    compPath = path.join componentsPath, name
                    if fs.statSync(compPath).isDirectory()
                        moduleInfo.components.push name

            pagesPath = path.join moduleInfo.path, 'pages'
            if fs.existsSync pagesPath
                for name in fs.readdirSync pagesPath
                    ctrlPath = path.join pagesPath, name
                    if fs.statSync(ctrlPath).isDirectory()
                        moduleInfo.pages.push name

            modelPath = path.join moduleInfo.path, 'model'
            if fs.existsSync modelPath
                for name in fs.readdirSync modelPath
                    name = path.parse(name).name
                    moduleInfo.model.push name

    else
        app.modules = require 'app-modules'


    for name in options.components or []
        app.component require name

    for moduleInfo in options.modules
        if _.isString moduleInfo
            moduleInfo = name: moduleInfo
        moduleName = moduleInfo.name
        _.defaults moduleInfo, app.modules[moduleName]

        require moduleName if moduleInfo.index

        if moduleInfo.opts
            opts = require moduleName + '/opts'
            _.assign opts, moduleInfo

        for name in moduleInfo.components
            compPath = path.join moduleInfo.path, 'components', name
            if moduleName
                comp = require moduleName + '/components/' + name
                comp::name = moduleName + ':' + name
            else
                comp = require 'components/' + name
                comp::name = name
            comp::view = compPath
            app.component comp

        for name in moduleInfo.pages
            ctrlPath = path.join moduleInfo.path, 'pages', name
            if moduleName
                ctrl = require moduleName + '/pages/' + name
                ctrl::name = moduleName + ':pages:' + name
            else
                ctrl = require 'pages/' + name
                ctrl::name = 'pages:' + name
            ctrl::view = ctrlPath
            if _.isString ctrl::path
                ctrl::path = moduleInfo.url + ctrl::path  or  '/'
            else
                ctrl::path =
                    for p in ctrl::path or []
                        moduleInfo.url + p
                    
            app.controller ctrl
        for name in moduleInfo.model
            app.proto[_.capitalize name] = require moduleName + '/model/' + name
            
            
            
    app.loadStyles dirname + '/styles'
    app.loadViews dirname + '/views'

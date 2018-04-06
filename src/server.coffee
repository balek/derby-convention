path = require 'path'

derby = require 'derby'
resolve = derby.util.serverRequire module, 'resolve'
fs = derby.util.serverRequire module, 'fs'

util = require './util'


        
resourceTypes =
    module:
        fileName: '*'
        directory: true
        parents: ['module']

    tasks:
        fileName: 'tasks'
        directory: true
        parents: ['module', 'server', 'pages', 'components']

    taskDir:
        fileName: '*'
        directory: true
        parents: ['tasks']
        
    task: [
        fileName: 'index'
        require: true
        parents: ['taskDir']
    ,
        fileName: '*'
        require: true
        parents: ['tasks']
    ]
    
    server:
        fileName: 'server'
        directory: true
        parents: ['module', 'pages', 'components', 'styles', 'views']

    common:
        fileName: 'common'
        directory: true
        parents: ['module', 'server', 'pages', 'components']
        
    styles:
        fileName: 'styles'
        directory: true
        parents: ['module', 'server', 'pages', 'components']

    style:
        fileName: 'index'
        extensions: ['.css', '.scss', '.sass']
        parents: ['module', 'server', 'pages', 'components', 'styles']

    views: [
        fileName: 'views'
        directory: true
        parents: ['module', 'server', 'pages', 'components', 'tasks', 'task']
    ,
        fileName: '*'
        directory: true
        parents: ['views']
    ]

    view: [
        fileName: 'index'
        extensions: ['.html', '.pug']
        parents: ['module', 'server', 'pages', 'components', 'tasks', 'task']
    ,
        fileName: '*'
        extensions: ['.html', '.pug']
        parents: ['views']
    ]

    express:
        fileName: 'express'
        require: true
        parents: ['module', 'server', 'pages', 'components']

    components: [
        fileName: 'components'
        directory: true
        parents: ['module', 'server', 'pages']
    ,
        fileName: '*'
        directory: true
        parents: ['components']
    ]
    
    modules:
        fileName: 'modules'
        require: true
        parents: ['module', 'server']
        
    moduleOpts:
        fileName: 'opts'
        require: true
        parents: ['module']
        
    component:
        fileName: 'index'
        require: true
        parents: ['components']
        
    pages: [
        fileName: 'pages'
        directory: true
        parents: ['module', 'server']
        forceIncludeName: true
    ,
        fileName: '*'
        directory: true
        parents: ['pages']
    ]
    
    page:
        fileName: 'index'
        require: true
        parents: ['pages']
        
    models:
        fileName: 'model'
        directory: true
        parents: ['module', 'server']
        
    model:
        fileName: '*'
        require: true
        parents: ['models']
        
    locales:
        fileName: 'locales'
        extensions: ['.yml']
        parents: ['module', 'server', 'pages', 'models', 'components', 'tasks', 'task']

    privileges:
        fileName: 'privileges'
        require: true
        parents: ['module', 'server', 'pages', 'components']

    hooks:
        fileName: 'hooks'
        require: true
        parents: ['module', 'server', 'pages', 'components', 'tasks', 'task']

    rpc:
        fileName: 'rpc'
        require: true
        parents: ['module', 'server', 'pages', 'components', 'tasks', 'task']


typesChildren = {}
for typeName, typeInfos of resourceTypes
    if not Array.isArray typeInfos
        typeInfos = [typeInfos]
        resourceTypes[typeName] = typeInfos
    typesChildren[typeName] ?= []
    for typeInfo in typeInfos
        for parent in typeInfo.parents
            children = typesChildren[parent] ?= []
            if typeInfo.fileName == '*'
                children.push typeName
            else
                children.unshift typeName

walk = (dirInfo, resources = {}) ->
    for fileFullName in fs.readdirSync dirInfo.filePath
        filePath = path.join dirInfo.filePath, fileFullName
        isDir = fs.statSync(filePath).isDirectory()
        {name: fileName, ext: fileExt} = path.parse fileFullName
        for childTypeName in typesChildren[dirInfo.type]
            childTypeInfos = resourceTypes[childTypeName]
            match = false
            for childTypeInfo in childTypeInfos
                continue unless dirInfo.type in childTypeInfo.parents
                continue if isDir != childTypeInfo.directory?
                continue if childTypeInfo.fileName not in ['*', fileName]
                extensions =
                    if childTypeInfo.require
                        Object.keys module.constructor._extensions
                    else
                        childTypeInfo.extensions
                continue unless isDir or fileExt in extensions
                resourceInfo =
                    parent: dirInfo
                    filePath: filePath
                    requirePath:
                        if dirInfo.requirePath
                            "#{dirInfo.requirePath}/#{fileName}"
                        else
                            fileName
                    name:
                        if childTypeInfo.fileName != '*' and not childTypeInfo.forceIncludeName
                            dirInfo.name
                        else
                            fileName
                    fullName:
                        if childTypeInfo.fileName != '*' and not childTypeInfo.forceIncludeName
                            dirInfo.fullName
                        else if dirInfo.fullName
                            "#{dirInfo.fullName}:#{fileName}"
                        else
                            fileName
                    type: childTypeName
                resourceInfo.forceIncludeName = childTypeInfo.forceIncludeName
                    
                if isDir
                    walk resourceInfo, resources
                else
                    resources[childTypeName] ?= []
                    resources[childTypeName].push resourceInfo
                    
                if childTypeName == 'modules'
                    modules = require filePath
                    for m in modules
                        modulePath = resolve.sync m.name, isFile: util.isDirectory, paths: globalPaths
                        moduleInfo =
                            type: m.type or 'module'
                            filePath: modulePath
                            requirePath: m.name
                        if m.url
                            moduleInfo.urlPart = m.url
                        walk moduleInfo, resources
                match = true
                break
            break if match
    resources


globalPaths = module.constructor.globalPaths
rootPath = resolve.sync '', isFile: util.isDirectory, paths: globalPaths, moduleDirectory: []
resources = walk type: 'module', filePath: rootPath
if resources.rpc
    derby.use require 'racer-rpc'


module.exports =
    resources: resources
    loadBackend: (backend) ->
        # if resources.hooks
        #     require('sharedb-hooks') backend
        # if resources.queries
        #     require('sharedb-server-query') backend
        # if resources.privileges
        #     require('sharedb-access') backend

        for r in resources.privileges or []
            privileges = require r.requirePath
            prefix = if r.name then "#{r.name}:" else ''
            for name, permissions of privileges
                fullName = prefix + name
                for role in permissions.$roles or []
                    backend.roles[role] ?= []
                    backend.roles[role].push fullName
                delete permissions.$roles
                backend.addPrivilege fullName, permissions


        for r in resources.rpc
            funcs = require r.requirePath
            for name, func of funcs
                do (name, func) ->
                    backend.rpc.on name, (args..., cb) ->
                        if Object::toString.call(cb) != '[object Function]'
                            args.push cb
                            cb = (err) ->
                                return unless err
                                console.error "Error in RPC function '#{name}' is not handled by client:", err
                        try
                            res = await func.call this, args...
                        catch e
                        cb e, res


        for r in resources.hooks
            backend.hooks require r.requirePath


        if resources.model
            derby.use require 'derby-ar'
            # Support for CoffeeScript class inheritance
            derby.Model.ChildModel::constructor = derby.Model.ChildModel

        for fileInfo in resources.model
            model = require fileInfo.requirePath
            model::name = fileInfo.name
            derby.model model::name, model::pattern, model
        

        for fileInfo in resources.modules
            modules = require fileInfo.requirePath
            for m in modules
                continue unless m.opts
                opts = require "#{m.name}/opts"
                Object.assign opts, m.opts

    loadApp: (app) ->
        # dirname = path.dirname app.filename
        setResourceUrl = (r) ->
            return if r.url?
            prefix =
                if r.parent
                    setResourceUrl r.parent
                    r.parent.url
                else
                    ''
                        
            postfix =
                switch r.type
                    when 'pages'
                        pageResource = resources.page.find (p) -> p.requirePath == r.requirePath + '/index'
                        if pageResource
                            page = require pageResource.requirePath
                        page?::$path ?
                            if r.forceIncludeName
                                ''
                            else
                                r.name
                    when 'module'
                        r.urlPart or r.name
            r.url =
                if postfix
                    if Array.isArray postfix
                        for p in postfix
                            "#{prefix}/#{p}"
                    else
                        "#{prefix}/#{postfix}"
                else
                    prefix
                
            if r.type == 'page'
                page = require r.requirePath
                if page::$render == false
                    r.url += '*'
                
        for resource in resources.page
            setResourceUrl resource
        for resource in resources.express
            setResourceUrl resource
        for resource in resources.view
            serverOnly = false
            ancestor = resource
            while ancestor = ancestor.parent
                if ancestor.type in ['server', 'tasks']
                    serverOnly = true
                    break
                    
            # app.loadViews resource.filePath, resource.fullName
            derbyFiles = derby.util.serverRequire module, 'derby/lib/files'
            data = derbyFiles.loadViewsSync app, resource.filePath, resource.fullName
            for item in data.views
                item.options.serverOnly = serverOnly
                app.views.register item.name, item.source, item.options
            if not derby.util.isProduction
                app._watchViews data.files, resource.filePath, resource.fullName

#                    when 'style'
#                        app.loadStyles r.filePath, r.fullName
#                    when 'express'
#                        app.expressRouters.push require r.filePath
#                    when 'locales'
#                        app.localeFiles[r.fullName] = r.filePath
        
        resources.page.sort (r1, r2) ->
            compare = (a, b) ->
                if a == b
                    0
                else if a < b
                    -1
                else
                    1

            p1 = require r1.requirePath
            p2 = require r2.requirePath
            res = compare p2::$weight or 0, p1::$weight or 0
            return res if res

            url1 = r1.url
            url2 = r2.url
            if Array.isArray url1
                url1 = url1[0]
            if Array.isArray url2
                url2 = url2[0]
            parts1 = url1.split '/'
            parts2 = url2.split '/'
            # res = compare parts1.length, parts2.length
            # return res if res

            for i of parts1
                return 1 if not parts2[i]?
                param1 = parts1[i].startsWith ':'
                param2 = parts2[i].startsWith ':'
                noRender1 = parts1[i].endsWith '*'
                noRender2 = parts2[i].endsWith '*'
                res = compare(param1, param2) or compare(noRender2, noRender1) or compare parts1[i], parts2[i]
                return res if res

            compare parts1.length, parts2.length


        app.on 'bundle', (bundler) ->
            clientModules = {}
            for t, val of resources
                clientModules[t] =
                    if t in ['rpc', 'locales', 'privileges', 'queries']
                        true
                    else if t in ['page', 'component', 'model', 'moduleOpts', 'modules']
                        val.filter (r) ->
                            ancestor = r
                            while ancestor = ancestor.parent
                                return if ancestor.type in ['server', 'tasks']
                            delete r.parent
                            delete r.filePath
                            delete r.type
                            bundler.require r.requirePath
                            true
            bundler.exclude '_auto-loaded-modules'
            a = new require('stream').Readable()
            a.push 'module.exports = ' + JSON.stringify clientModules
            a.push null
            bundler.require a, expose: '_auto-loaded-modules'

        app.serverUse module, './sass-auto'
        app.loadStyles rootPath + '/styles'

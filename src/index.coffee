derby = require 'derby'


derby.use require '../subcomponents'


module.exports = (app) ->
    resources =
        if derby.util.isServer
            module.exports.loadApp app
            module.exports.resources
        else
            ### eslint-disable-next-line node/no-missing-require ###
            require '_auto-loaded-modules'
        
    app.use require 'derby-controller'
    # if resources.locales
    #     app.use require 'derby-l10n'
    if resources.rpc
        derby.use require 'racer-rpc'
    # if resources.privileges
    #     Object.assign app.proto, require 'sharedb-access'

    for fileInfo in resources.component
        component = require fileInfo.requirePath
        component::name = fileInfo.fullName
        app.component component

    for fileInfo in resources.page
        page = require fileInfo.requirePath
        page::$path = fileInfo.url or '/'
        if page::$render == false
            delete page::$render
        else
            page::name = fileInfo.fullName
        app.controller page

        for comp in page::components or []
            comp::name = "#{page::name}:#{comp::name}"
            app.component comp


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


Object.assign module.exports, derby.util.serverRequire module, './server'
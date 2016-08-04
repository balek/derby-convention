derby = require 'derby'
fs = derby.util.serverRequire module, 'fs'

module.exports =
    isDirectory: (file) ->
        try
            stat = fs.statSync file
        catch err
            if err and err.code == 'ENOENT'
                return false
        return stat.isDirectory()
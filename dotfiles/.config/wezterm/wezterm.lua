local Config = require('config')

return Config:init()
    :append(require('config.ui'))
    :append(require('config.keys')).options

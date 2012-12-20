ko = require 'ko'
require 'libs/bindings'

Router = require 'libs/router'

TemplateEngine  = require 'libs/template_engine'
CommonViewModel = require 'view_models/common'

ko.setTemplateEngine new TemplateEngine
cmv = new CommonViewModel

do (new Router).refresh

ko.applyBindings cmv

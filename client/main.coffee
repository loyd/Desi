ko = require 'ko'
require 'libs/bindings'

Router         = require 'libs/router'
TemplateEngine = require 'libs/template_engine'
CommonMVM      = require 'sections/common'

ko.setTemplateEngine new TemplateEngine
commonMVM = new CommonMVM

do (new Router).refresh

ko.applyBindings commonMVM

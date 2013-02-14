ko = require 'ko'
require 'libs/bindings'
require 'libs/observable_extenders'

Router          = require 'libs/router'
TemplateEngine  = require 'libs/template_engine'
CommonViewModel = require 'view_models/common'

ko.setTemplateEngine new TemplateEngine
common = new CommonViewModel

do (new Router).refresh

ko.applyBindings common, document.querySelector('#ko-body')

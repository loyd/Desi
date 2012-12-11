ko = require 'ko'
require 'libs/bindings'

TemplateEngine  = require 'libs/template_engine'
CommonViewModel = require 'view_models/common'

ko.applyBindings new CommonViewModel
ko.setTemplateEngine new TemplateEngine
module.exports = [{
	name : 'java'
	ext : '.java'
	content : '''
{{##def.impl:{{~it.realizations :r:i}}{{? i != 0}},{{??}} implements {{?}}{{=r.name}}{{~}}#}}
{{##def.params:{{~oper.params :p:j}}{{? j != 0}}, {{?}}{{=p.type}} {{=p.name}}{{~}}#}}

class {{=it.name}}{{?it.parent}} extends {{=it.parent.name}}{{?}}{{#def.impl}} {
{{~it.attributes :attr}}
    {{= attr.visibility}}{{?attr.isStatic}} static{{?}} {{= attr.type}} {{=attr.name}};
{{~}}{{~it.operations :oper}}
    {{= oper.visibility}}{{?oper.isStatic}} static{{?}} {{= oper.type}} {{=oper.name}}({{#def.params}}) {}
{{~}}
}
	'''
}]
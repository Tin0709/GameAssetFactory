"""Small, fail-closed Molang interpreter for the audited research source.

No Python eval, imports, attribute access, indexing or arbitrary code execution.
Only explicitly listed Math functions and caller-supplied q.* callables are callable.
Expressions are parsed once and branches execute lazily. This implements the
source subset, not the complete Bedrock VM. Numeric errors return zero (Molang);
unsupported grammar/functions raise MolangError. Math.min_angle's 180 tie maps
 to -180; exact tie behavior is an explicit adapter convention.
"""
from functools import lru_cache
import math
import re


class MolangError(ValueError):
    """Unsupported syntax or function in the restricted source interpreter."""


_TOKEN = re.compile(r"\s*(?:(\d+(?:\.\d*)?(?:[eE][+-]?\d+)?|\.\d+(?:[eE][+-]?\d+)?)|([A-Za-z_][A-Za-z_0-9.]*)|('(?:[^'\\]|\\.)*'|\"(?:[^\"\\]|\\.)*\")|(==|!=|<=|>=|&&|\|\||\?\?|[+*/%<>=!?:;,(){}-]))")
_PRECEDENCE = {'=':1, '?':2, '??':3, '||':4, '&&':5,
               '==':6, '!=':6, '<':7, '>':7, '<=':7, '>=':7,
               '+':8, '-':8, '*':9, '/':9, '%':9}


class _Parser:
    def __init__(self, text):
        self.tokens=[]
        pos=0
        while pos<len(text):
            if not text[pos:].strip(): break
            match=_TOKEN.match(text,pos)
            if not match: raise MolangError('Unsupported token at offset %d: %r' % (pos,text[pos:pos+24]))
            number,name,string,operator=match.groups()
            self.tokens.append(('number',float(number)) if number is not None else
                               ('name',name.lower()) if name else
                               ('string',string[1:-1]) if string else ('op',operator))
            pos=match.end()
        self.tokens.append(('eof','<eof>'))
        self.i=0

    def peek(self): return self.tokens[self.i][1]
    def pop(self):
        value=self.tokens[self.i];self.i+=1;return value
    def accept(self,value):
        if self.peek()==value: self.pop();return True
        return False
    def expect(self,value):
        if not self.accept(value): raise MolangError('Expected %r, found %r' % (value,self.peek()))

    def program(self, end='<eof>'):
        nodes=[]
        while self.peek()!=end:
            if self.peek()=='<eof>': raise MolangError('Unclosed block')
            if self.accept(';'): continue
            if self.accept('return'): nodes.append(('return',self.expression()))
            else: nodes.append(self.expression())
            if self.peek()!=end: self.expect(';')
        return ('program',tuple(nodes))

    def expression(self, minimum=1):
        kind,value=self.pop()
        if kind in ('number','string'): left=('literal',value)
        elif value in ('!','-','+'):
            left=('unary',value,self.expression(10))
        elif value=='(':
            left=self.expression();self.expect(')')
        elif value=='{':
            left=self.program('}');self.expect('}')
        elif kind=='name':
            if value in ('true','false'): left=('literal',int(value=='true'))
            elif self.accept('('):
                args=[]
                if self.peek()!=')':
                    args.append(self.expression())
                    while self.accept(','): args.append(self.expression())
                self.expect(')');left=('call',value,tuple(args))
            elif value.startswith(('v.','variable.','t.','temp.','q.','query.')) or value=='this':
                left=('variable',value)
            else: raise MolangError('Unsupported identifier: '+str(value))
        else: raise MolangError('Unexpected expression token: '+str(value))
        while self.peek() in _PRECEDENCE and _PRECEDENCE[self.peek()]>=minimum:
            op=self.pop()[1];precedence=_PRECEDENCE[op]
            if op=='?':
                yes=self.expression()
                no=self.expression(precedence) if self.accept(':') else ('literal',0.0)
                left=('conditional',left,yes,no)
            elif op=='=':
                if left[0]!='variable' or not left[1].startswith(('v.','variable.','t.','temp.')):
                    raise MolangError('Assignment requires a v.* or t.* variable')
                left=('assign',left[1],self.expression(precedence))
            else: left=('binary',op,left,self.expression(precedence+1))
        return left


@lru_cache(maxsize=4096)
def _compile(text):
    parser=_Parser(text)
    return parser.program()


def _name(name):
    for long,short in [('variable.','v.'),('query.','q.'),('temp.','t.')]:
        if name.startswith(long): return short+name[len(long):]
    return name


_MATH = {
    'sin':lambda x:math.sin(math.radians(x)),
    'cos':lambda x:math.cos(math.radians(x)),
    'atan':lambda x:math.degrees(math.atan(x)),
    'atan2':lambda y,x:math.degrees(math.atan2(y,x)),
    'abs':abs, 'min':min, 'max':max, 'pow':math.pow, 'sqrt':math.sqrt,
    'exp':math.exp, 'floor':math.floor, 'ceil':math.ceil,
    'round':lambda x:math.floor(x+0.5),
    'mod':math.fmod,
    'clamp':lambda x,lo,hi:min(hi,max(lo,x)),
    'lerp':lambda a,b,t:a+(b-a)*t,
    'min_angle':lambda x:(x+180.0)%360.0-180.0,
    'sign':lambda x:float(x>0)-float(x<0),
    'hermite_blend':lambda x:x*x*(3.0-2.0*x),
}


class _Return(Exception):
    def __init__(self,value): self.value=value


class Molang:
    def __init__(self, env):
        self.env=env

    def eval(self,text):
        if isinstance(text,(float,int,bool)): return float(text)
        if not isinstance(text,str): raise MolangError('Expression must be text or number')
        try: return self._execute(_compile(text))
        except _Return as result: return result.value

    def _execute(self,node):
        tag=node[0]
        if tag=='literal': return node[1]
        if tag=='variable': return self.env.get(_name(node[1]),0.0)
        if tag=='assign':
            value=self._execute(node[2]);self.env[_name(node[1])]=value;return value
        if tag=='return': raise _Return(self._execute(node[1]))
        if tag=='program':
            value=0.0
            for child in node[1]: value=self._execute(child)
            # Complex Molang programs require return; source side-effect blocks
            # do not depend on their implicit result.
            return value if len(node[1])==1 else 0.0
        if tag=='conditional':
            return self._execute(node[2] if self._execute(node[1]) else node[3])
        if tag=='unary':
            value=self._execute(node[2])
            return float(not value) if node[1]=='!' else -value if node[1]=='-' else +value
        if tag=='binary':
            op=node[1];a=self._execute(node[2])
            if op=='&&': return float(bool(a) and bool(self._execute(node[3])))
            if op=='||': return float(bool(a) or bool(self._execute(node[3])))
            if op=='??': return a if a is not None else self._execute(node[3])
            b=self._execute(node[3])
            try:
                if op=='+': return a+b
                if op=='-': return a-b
                if op=='*': return a*b
                if op=='/': return a/b if b else 0.0
                if op=='%': return math.fmod(a,b) if b else 0.0
                if op=='==': return float(a==b)
                if op=='!=': return float(a!=b)
                if op=='<': return float(a<b)
                if op=='>': return float(a>b)
                if op=='<=': return float(a<=b)
                if op=='>=': return float(a>=b)
            except (ArithmeticError,ValueError): return 0.0
            raise MolangError('Unsupported binary operator '+op)
        if tag=='call':
            name=_name(node[1]);args=[self._execute(a) for a in node[2]]
            if name.startswith('math.'):
                function=_MATH.get(name[5:])
                if function is None: raise MolangError('Unsupported Math function '+name)
            elif name.startswith('q.'):
                function=self.env.get(name)
                if not callable(function): raise MolangError('Query is not a supplied callable: '+name)
            else: raise MolangError('Unsupported function '+name)
            try: return function(*args)
            except (ArithmeticError,ValueError): return 0.0
            except TypeError as error: raise MolangError('Invalid arguments to '+name) from error
        raise MolangError('Unsupported AST node '+tag)

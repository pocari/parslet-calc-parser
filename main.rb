require 'parslet'
require 'bigdecimal'

class CalcParser < Parslet::Parser
  root(:program)

  rule(:program) {
    (expression >> (scolon | newline).maybe).repeat.as(:program)
  }
  rule(:expression) {
    fundef.as(:fundef) |
    funcall.as(:funcall) |
    ident.as(:left) >> asign_op >> expression.as(:right) |
    term.as(:left) >> (exp_op >> expression.as(:right)).maybe
  }
  rule(:term) { primary.as(:left) >> (term_op >> term.as(:right)).maybe }
  rule(:primary) {
    number |
    (lparen >> expression >> rparen) |
    ident
  }
  rule(:fundef) {
    kdef >> ident >> lparen >> fundef_arg_list.as(:args) >> rparen >> (scolon | newline).maybe >> program.as(:body) >> kend
  }
  rule(:number) { (double | integer).as(:number) >> space?}
  rule(:double) { integer >> (str('.') >> match('\d').repeat(1)) }
  rule(:integer) { (match('[-+]').maybe >> match('[1-9]') >> match('\d').repeat) }
  rule(:ident) { reserved.absent? >> (match('[_a-zA-Z]') >> match('[_a-zA-Z0-9]').repeat).as(:ident) >> space? }
  rule(:funcall) { ident >> lparen >> funcall_arg_list.as(:args) >> rparen }
  rule(:funcall_arg_list) { (expression.as(:arg) >> (comma >> expression).as(:arg).repeat).maybe }
  rule(:fundef_arg_list) { (ident.as(:arg) >> (comma >> ident).as(:arg).repeat).maybe }

  rule(:lparen) { str('(') >> space? }
  rule(:rparen) { str(')') >> space? }
  rule(:exp_op) { match('[-+]').as(:op) >> space? }
  rule(:term_op) { match('[*/]').as(:op) >> space? }
  rule(:asign_op) { str('=').as(:op) >> space? }
  rule(:space) { match('\s').repeat }
  rule(:space?) { space.maybe }
  rule(:newline) { match('[\r\n]') }
  rule(:scolon) { str(';') >> space? }
  rule(:comma) { str(',') >> space? }
  rule(:kdef) { str('def') >> space? }
  rule(:kend) { str('end') >> space? }
  rule(:reserved) {
    kdef |
    kend
  }
end

class EvalContext
  attr_accessor :variables, :functions

  def initialize
    @variables = {}
    @functions = builtin_functions
  end

  BUILTIN_FUNCTION_NAMES = %w(
    puts
    print
  )

  def builtin_functions
    BUILTIN_FUNCTION_NAMES.each.with_object({}) do |name, obj|
      obj[name] = BuiltinFunction.new(method(name))
    end
  end
end

NumericNode = Struct.new(:value) do
  def eval(context)
    # BigDecimal(value)
    value.to_f
  end
end

BuiltinFunction = Struct.new(:body) do
  def apply(args, context)
    body.call(*args.map{|e| e.eval(context)})
  end
end

UserDefinedFunction = Struct.new(:name, :dargs, :body) do
  def apply(args, context)
    new_context = EvalContext.new
    new_context.functions = context.functions
    new_context.variables = context.variables.dup

    if dargs.size != args.size
      raise "UserDefinedFunction: #{name} wrong number of arguments (given #{args.size}, expected #{dargs.size})"
    end

    dargs.zip(args).each do |da, aa|
      new_context.variables[da.ident] = aa.eval(context)
    end
    body.eval(new_context)
  end
end

VariableNode = Struct.new(:ident) do
  def eval(context)
    unless context.variables.has_key?(ident)
      raise "#{ident} is not defined."
    end
    context.variables[ident]
  end
end

FundefNode = Struct.new(:func, :dargs, :body) do
  def eval(context)
    context.functions[func] = UserDefinedFunction.new(func, dargs, body)
  end
end

FuncallNode = Struct.new(:func, :args) do
  def eval(context)
    unless context.functions.has_key?(func)
      raise "#{func} is not defined."
    end
    context.functions[func].apply(args, context)
  end
end

AssignNode = Struct.new(:var, :expression) do
  def eval(context)
    raise "invalid asign operation: #{var}" unless VariableNode === var
    context.variables[var.ident] = expression.eval(context)
  end
end

BinOpNode = Struct.new(:op, :left, :right) do
  def eval(context)
    l = left.eval(context)
    r = right.eval(context)
    case op
    when '-'
      l - r
    when '+'
      l + r
    when '/'
      l / r
    when '*'
      l * r
    else
      raise "unexpected operator: #{op}"
    end
  end
end

ProgramNode = Struct.new(:seq) do
  def eval(context)
    # とりあえず最後のnodeのeval結果を返すようにしておく
    seq.inject(nil) do |acc, node|
      node.eval(context)
    end
  end
end

class AstBuilder < Parslet::Transform
  rule(left: simple(:x)) { x }

  rule(arg: simple(:x)) { x }

  rule(number: simple(:x)) {
    NumericNode.new(x.to_s)
  }

  rule(fundef: subtree(:tree)) {|d|
    func = d[:tree][:ident]
    args = d[:tree][:args]
    body = d[:tree][:body]
    FundefNode.new(func.to_s, args, body)
  }

  rule(funcall: subtree(:tree)) { |d|
    func = d[:tree][:ident]
    args = d[:tree][:args]
    args = args.is_a?(Array) ? args : [args]
    FuncallNode.new(func.to_s, args)
  }

  rule(ident: simple(:x)) { |d|
    VariableNode.new(d[:x].to_s)
  }

  rule(
    left: simple(:l),
    op: simple(:op),
    right: simple(:r)
  ) { |d|
    op, l, r = d[:op], d[:l], d[:r]
    if op == '='
      AssignNode.new(l, r)
    else
      BinOpNode.new(op, l, r)
    end
  }

  rule(program: sequence(:seq)) {
    ProgramNode.new(seq)
  }
end

def output_detail?
  ENV['OUTPUT_DETAIL'] == '1'
end

def xputs(*args)
  puts(*args) if output_detail?
end

def xpp(*args)
  pp(*args) if output_detail?
end

begin
  # raw = '(1 + 2) * 3'
  raw = STDIN.read
  xputs "========================== raw input"
  xpp raw

  parsed = CalcParser.new.parse(raw)
  xputs "========================== syntax tree"
  xpp parsed

  ast = AstBuilder.new.apply(parsed)
  xputs "========================== AST"
  xpp ast

  xputs "========================== AST eval"
  ast.eval(EvalContext.new)
rescue Parslet::ParseFailed => failure
  puts failure.parse_failure_cause.ascii_tree
  raise failure
end

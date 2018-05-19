require 'parslet'
require 'bigdecimal'

class CalcParser < Parslet::Parser
  root(:program)

  rule(:program) {
    (expression >> (scolon | newline).maybe).repeat.as(:program)
  }
  rule(:expression) {
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
  rule(:number) { (double | integer).as(:number) >> space?}
  rule(:double) { integer >> (str('.') >> match('\d').repeat(1)) }
  rule(:integer) { (match('[-+]').maybe >> match('[1-9]') >> match('\d').repeat) }
  rule(:ident) { (match('[_a-zA-Z]') >> match('[_a-zA-Z0-9]').repeat).as(:ident) >> space? }
  rule(:funcall) { ident >> lparen >> arg_list.as(:args) >> rparen }
  rule(:arg_list) { (expression.as(:arg) >> (comma >> expression).as(:arg).repeat).maybe }

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
end

class EvalContext
  attr_reader :variables
  attr_reader :functions

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
      obj[name] = BuiltinFunctionNode.new(method(name))
    end
  end

  def inspect
    "#<EvalContext>"
  end
end

NumericNode = Struct.new(:value) do
  def eval
    # BigDecimal(value)
    value.to_f
  end
end

BuiltinFunctionNode = Struct.new(:body) do
  def apply(args)
    body.call(*args.map(&:eval))
  end
end

VariableNode = Struct.new(:ident, :context) do
  def eval
    unless context.variables.has_key?(ident)
      raise "#{ident} is not defined."
    end
    context.variables[ident]
  end
end

FuncallNode = Struct.new(:func, :args, :context) do
  def eval
    unless context.functions.has_key?(func)
      raise "#{func} is not defined."
    end
    context.functions[func].apply(args)
  end
end

AssignNode = Struct.new(:var, :expression, :context) do
  def eval
    raise "invalid asign operation: #{var}" unless VariableNode === var
    context.variables[var.ident] = expression.eval
  end
end

BinOpNode = Struct.new(:op, :left, :right) do
  def eval
    l = left.eval
    r = right.eval
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
  def eval
    # とりあえず最後のnodeのeval結果を返すようにしておく
    seq.inject(nil) do |acc, node|
      node.eval
    end
  end
end

class AstBuilder < Parslet::Transform
  # evalする際のコンテキストをクラスインスタンス変数で定義しておく
  @context = EvalContext.new

  rule(left: simple(:x)) { x }

  rule(arg: simple(:x)) { x }

  rule(number: simple(:x)) {
    NumericNode.new(x.to_s)
  }

  rule(funcall: subtree(:tree)) { |d|
    func = d[:tree][:ident]
    args = d[:tree][:args]
    args = args.is_a?(Array) ? args : [args]
    FuncallNode.new(func.to_s, args, @context)
  }

  rule(ident: simple(:x)) { |d|
    VariableNode.new(d[:x].to_s, @context)
  }

  rule(
    left: simple(:l),
    op: simple(:op),
    right: simple(:r)
  ) { |d|
    op, l, r = d[:op], d[:l], d[:r]
    if op == '='
      AssignNode.new(l, r, @context)
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
  ast.eval
rescue Parslet::ParseFailed => failure
  puts failure.parse_failure_cause.ascii_tree
  raise failure
end

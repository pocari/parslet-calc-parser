require 'parslet'
require 'bigdecimal'

class CalcParser < Parslet::Parser
  root(:program)

  rule(:program) {
    (expression >> (scolon | newline).maybe).repeat.as(:program)
  }
  rule(:expression) {
    ident.as(:left) >> asign_op >> expression.as(:right) |
    term.as(:left) >> (exp_op >> expression.as(:right)).maybe
  }
  rule(:term) { primary.as(:left) >> (term_op >> term.as(:right)).maybe }

  rule(:primary) { number | (lparen >> expression >> rparen) | ident}
  rule(:number) { (double | integer).as(:number) >> space?}
  rule(:double) { integer >> (str('.') >> match('\d').repeat(1)) }
  rule(:integer) { (match('[-+]').maybe >> match('[1-9]') >> match('\d').repeat) }
  rule(:ident) { (match('[_a-zA-Z]') >> match('[_a-zA-Z0-9]').repeat).as(:ident) >> space? }

  rule(:lparen) { str('(') >> space? }
  rule(:rparen) { str(')') >> space? }
  rule(:exp_op) { match('[-+]').as(:op) >> space? }
  rule(:term_op) { match('[*/]').as(:op) >> space? }
  rule(:asign_op) { str('=').as(:op) >> space? }

  rule(:space) { match('\s').repeat }
  rule(:space?) { space.maybe }

  rule(:newline) { match('[\r\n]') }
  rule(:scolon) { str(';') >> space }
end

class EvalContext
  attr_reader :variables

  def initialize
    @variables = {}
  end
end

NumericNode = Struct.new(:value) do
  def eval
    BigDecimal(value)
  end
end

VariableNode = Struct.new(:ident, :context) do
  def eval
    p [:variable_eval, context]
    unless context.variables.has_key?(ident)
      raise "#{ident} is not defined."
    end
    context.variables[ident]
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

  rule(number: simple(:x)) {
    NumericNode.new(x.to_s)
  }

  rule(left: simple(:x)) {
    x
  }

  rule(ident: simple(:x)) { |d|
    VariableNode.new(d[:x].to_s, @context)
  }

  rule(
    left: simple(:l),
    op: simple(:op),
    right: simple(:r)
  ) { |d|
    p [:test, @context]
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

begin
  # raw = '(1 + 2) * 3'
  raw = STDIN.read
  puts "========================== raw input"
  pp raw

  parsed = CalcParser.new.parse(raw)
  puts "========================== syntax tree"
  pp parsed

  ast = AstBuilder.new.apply(parsed)
  puts "========================== AST"
  pp ast

  puts "========================== AST eval"
  pp ast.eval
rescue Parslet::ParseFailed => failure
  puts failure.parse_failure_cause.ascii_tree
  raise failure
end

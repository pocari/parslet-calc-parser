require 'parslet'
require 'bigdecimal'

class CalcParser < Parslet::Parser
  root(:expression)

  rule(:expression) { term.as(:left) >> (exp_op >> expression.as(:right)).maybe }
  rule(:term) { primary.as(:left) >> (term_op >> term.as(:right)).maybe }

  rule(:primary) { number | (lparen >> expression >> rparen) }
  rule(:number) { (double | integer).as(:number) >> space?}
  rule(:double) { integer >> (str('.') >> match('\d').repeat(1)) }
  rule(:integer) { (match('[-+]').maybe >> match('[1-9]') >> match('\d').repeat) }

  rule(:lparen) { str('(') >> space? }
  rule(:rparen) { str(')') >> space? }
  rule(:exp_op) { match('[-+]').as(:op) >> space? }
  rule(:term_op) { match('[*/]').as(:op) >> space? }

  rule(:space) { match('\s').repeat }
  rule(:space?) { space.maybe }
end

NumericNode = Struct.new(:value) do
  def eval
    BigDecimal(value)
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

class AstBuilder < Parslet::Transform
  rule(number: simple(:x)) { NumericNode.new(x.to_s) }
  rule(left: simple(:x)) { x }
  rule(
    left: simple(:l),
    op: simple(:op),
    right: simple(:r)
  ) { BinOpNode.new(op, l, r) }
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
  pp ast.eval.to_f
rescue Parslet::ParseFailed => failure
  puts failure.parse_failure_cause.ascii_tree
  raise failure
end

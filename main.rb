require_relative 'calc_parser.rb'

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

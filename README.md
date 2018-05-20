# Parslet sample

## run sample

```
# clone this repo
% git clone git@github.com:pocari/parslet-calc-parser.git
% cd parslet-calc-parser

# install bundles
% bundle install --path=vendor/bundle

# show sample
% cat program.txt
def add(aaa, bbb)
  x = (1 + 2) * 3
  aaa + bbb + x
end

aaa = 1
bbb = 3
ccc = add((aaa + 2), bbb)

puts(aaa)
puts(bbb)
puts(ccc)

# run sampl
% bundle exec ruby main.rb < program.txt
1.0
3.0
15.0
```


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
aaa = 1; bbb = 3
ccc = (aaa + 2) + bbb
puts(ccc + 1)

# run sampl
% bundle exec ruby main.rb < program.txt
7.0
```


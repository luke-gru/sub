#!/usr/bin/env ruby

new_argv = []
sub_str = nil

if ARGV.size == 0
  require "readline"
  line = Readline.readline "cmd: ", true
  new_argv.replace line.strip.split(' ')
  line = Readline.readline "sub: ", true
  sub_str = line.strip
else
  ARGV.each_with_index do |arg, i|
    if arg == '--'
      sub_str = ARGV[i+1]
      if ARGV[i+2]
        $stderr.puts "Warning: ignoring everything after pattern: #{ARGV[i+2..-1].join(' ')}"
      end
      break
    else
      new_argv << arg
    end
  end
end


if sub_str.nil?
  cmd = new_argv.shift
  exec cmd, *new_argv
end

prev, new, flags = sub_str.split('/')
prev = prev.to_s.dup
new = new.to_s.dup
flags = flags.to_s.dup
flag_dryrun = flags.include?('d')
flag_verbose = flags.include?('v')
flag_first = flags.include?('f')
flag_last = flags.include?('l')
flag_expand_star = flags.include?('e')
prev.strip!
new.strip!
flags.strip!
if prev.empty?
  $stderr.puts "#{$0}: Incorrect pattern, format is: prev_pat/new_pat"
  exit 1
end
prev_pat = Regexp.new(prev)

stop_subst = false
num_replacements = 0

new_argv.map! do |arg|
  if arg =~ prev_pat && !stop_subst
    stop_subst = true if flag_first
    new_arg = arg.sub(prev_pat, new)
    if flag_verbose && new_arg != arg && !flag_last
      num_replacements += 1
    end
    if new_arg != arg
      [arg, new_arg]
    else
      new_arg
    end
  else
    arg
  end
end

new_argv.reject! { |arg| Array(arg).last.strip.empty? }

if flag_last
  last_subst_el = nil
  new_argv.reverse.find { |e| Array === e ? last_subst_el = e : nil }
  new_argv.map! do |arg|
    case arg
    when String
      arg
    when Array
      if last_subst_el.equal?(arg)
        num_replacements += 1
        arg[1]
      else
        arg[0]
      end
    end
  end
else
  new_argv.map! do |arg|
    case arg
    when String
      arg
    when Array
      arg[1]
    end
  end
end

if flag_expand_star
  new_argv.map! do |arg|
    if arg == '*'
      Dir['*'].to_a
    else
      arg
    end
  end
  new_argv.flatten!
end

if flag_verbose
  puts "#{num_replacements} replacement#{'s' if num_replacements != 1}"
end

if new_argv.empty?
  puts "Nothing to execute"
  exit 0
end
cmd = new_argv.shift
suffix = +""
suffix << " # (dry run)" if flag_dryrun
puts "Executing #{cmd} #{new_argv.join(' ')}#{suffix}"
exit 0 if flag_dryrun
exec cmd, *new_argv

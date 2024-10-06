#!/usr/bin/env ruby

def parse_argv_and_sub_str(argv)
  new_argv = []
  sub_str = nil
  if argv.size == 0
    require "readline"
    line = Readline.readline "cmd: ", true
    new_argv.replace line.strip.split(' ')
    line = Readline.readline "sub: ", true
    sub_str = line.strip
  else
    last_dashdash_idx = argv.rindex('--')
    argv.each_with_index do |arg, i|
      if arg == '--' && i == last_dashdash_idx
        sub_str = argv[i+1]
        if argv[i+2]
          $stderr.puts "Warning: ignoring everything after pattern: #{argv[i+2..-1].join(' ')}"
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
  [new_argv, sub_str]
end

new_argv, sub_str = parse_argv_and_sub_str(ARGV)

def flag(flags_str, char)
  flag = flags_str.include?(char)
  flags_str.delete!(char)
  flag
end

def parse_sub_str(sub_str)
  prev, new, flags = sub_str.split('/')
  prev = prev.to_s.dup
  new = new.to_s.dup
  flags = flags.to_s.dup
  flags.strip!
  flag_dryrun = flag flags, 'd'
  flag_verbose = flag flags, 'v'
  flag_first = flag flags, 'f'
  flag_last = flag flags, 'l'
  flag_expand_star = flag flags, 'e'
  flag_literal = flag flags, 'L'
  flag_ignorecase = flag flags, 'i'
  flag_debug = flag flags, 'D'
  flags_hash = {
    dryrun: flag_dryrun,
    verbose: flag_verbose,
    first: flag_first,
    last: flag_last,
    expand_star: flag_expand_star,
    literal: flag_literal,
    ignorecase: flag_ignorecase,
    debug: flag_debug
  }
  prev.strip!
  new.strip!

  unless flags.empty?
    $stderr.puts "Warning: unknown flag#{'s' if flags.size != 1}: #{flags}"
  end

  [prev, new, flags_hash]
end

prev, new, flags = parse_sub_str(sub_str)

if prev.empty?
  $stderr.puts "#{$0}: Incorrect pattern, format is: prev_pat/new"
  exit 1
end

def build_regexp(literal, flags)
  regexp_opts = +''
  regexp_opts << 'i' if flags.fetch(:ignorecase)
  if flags.fetch(:literal)
    Regexp.new Regexp.escape(literal), regexp_opts
  else
    Regexp.new(literal, regexp_opts)
  end
end

prev_pat = build_regexp(prev, flags)

def new_argv_replace!(new_argv, prev_pat, new, flags)
  stop_subst = false
  num_replacements = 0

  new_argv.map! do |arg|
    if arg =~ prev_pat && !stop_subst
      stop_subst = true if flags.fetch(:first)
      new_arg = arg.sub(prev_pat, new)
      if flags.fetch(:verbose) && new_arg != arg && !flags.fetch(:last)
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

  if flags.fetch(:last)
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

  if flags.fetch(:expand_star)
    new_argv.map! do |arg|
      if arg == '*'
        Dir['*'].to_a
      else
        arg
      end
    end
    new_argv.flatten!
  end
  num_replacements
end

num_replacements = new_argv_replace!(new_argv, prev_pat, new, flags)

def exec_cmd(new_argv, prev_pat, num_replacements, flags)
  if flags.fetch(:debug)
    puts "Pattern: #{prev_pat.inspect}"
  end
  if flags.fetch(:verbose)
    puts "#{num_replacements} replacement#{'s' if num_replacements != 1}"
  end

  if new_argv.empty?
    puts "Nothing to execute"
    exit 0
  end
  cmd = new_argv.shift
  suffix = +""
  suffix << " # (dry run)" if flags.fetch(:dryrun)
  puts "Executing #{cmd} #{new_argv.join(' ')}#{suffix}"
  exit 0 if flags.fetch(:dryrun)
  begin
    exec cmd, *new_argv
  rescue SystemCallError => e
    if e.class == Errno::ENOENT
      $stderr.puts "#{cmd}: command not found"
    else
      $stderr.puts "#{e.class}: #{e.message}"
    end
    exit e.errno
  end
end

exec_cmd(new_argv, prev_pat, num_replacements, flags)

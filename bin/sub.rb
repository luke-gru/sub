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
          $stderr.puts "Warning: ignoring everything after the pattern, which is: #{argv[i+2..-1].join(' ')}"
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
  flag_first_match = flag flags, 'f'
  flag_last_match = flag flags, 'l'
  flag_expand_star = flag flags, 'e'
  flag_literal = flag flags, 'L'
  flag_ignorecase = flag flags, 'i'
  flag_interactive = flag(flags, 'I') || ARGV.size == 0
  flag_output_only = flag flags, 'o'
  flag_copy_to_clipboard = flag flags, 'c'
  flag_verbose = flag flags, 'v'
  flag_debug = flag flags, 'D'
  flags_hash = {
    first_match: flag_first_match,
    last_match: flag_last_match,
    expand_star: flag_expand_star,
    literal: flag_literal,
    ignorecase: flag_ignorecase,
    interactive: flag_interactive,
    output_only: flag_output_only,
    copy_to_clipboard: flag_copy_to_clipboard,
    verbose: flag_verbose,
    debug: flag_debug,
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
  $stderr.puts "Incorrect pattern, format is: prev_pat/new"
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
      stop_subst = true if flags.fetch(:first_match)
      new_arg = arg.sub(prev_pat, new)
      if flags.fetch(:verbose) && new_arg != arg && !flags.fetch(:last_match)
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

  if flags.fetch(:last_match)
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

def copy!(cmd_line, flags)
  cmd_line = cmd_line.dup
  cmd_line << "\n" if cmd_line.empty?
  if /linux/i =~ RUBY_PLATFORM
    copy_bin = "xclip"
    copy_cmd = "xclip -selection clipboard"
    copy_proc = lambda do |f|
      system("#{copy_cmd} < #{f.path}", out: "/dev/null")
    end
  elsif /darwin/i =~ /RUBY_PLATFORM/
    copy_bin = "pbcopy"
    copy_cmd = copy_bin
    copy_proc = lambda do |f|
      system("cat #{f.path} | #{copy_cmd}", out: "/dev/null")
    end
  else
    $stderr.puts "Warning: don't know how to get copy command for #{RUBY_PLATFORM}"
    flags[:output_only] = true
    return
  end
  system("which #{copy_bin}", out: "/dev/null")
  unless $?.success?
    $stderr.puts "Warning: can't find #{copy_bin}, please install it and put it in your PATH"
    flags[:output_only] = true
    return
  end
  require "tempfile"
  Tempfile.create("sub_cmd") do |f|
    f.write cmd_line
    f.flush
    copy_proc.call(f)
    puts "Copied" if $?.success?
  end
end

def exec_cmd(new_argv, prev_pat, num_replacements, flags)
  if flags.fetch(:debug)
    puts "Pattern: #{prev_pat.inspect}"
  end
  if flags.fetch(:verbose)
    puts "#{num_replacements} replacement#{'s' if num_replacements != 1}"
  end

  if new_argv.empty?
    copy!("", flags) if flags.fetch(:copy_to_clipboard)
    if flags.fetch(:output_only)
      puts ""
    else
      puts "Nothing to execute"
    end
    exit 0
  end

  cmd = new_argv.shift
  cmd_line = "#{cmd} #{new_argv.join(' ')}"
  action = flags.fetch(:copy_to_clipboard) ? "copy" : "execute"
  if flags.fetch(:interactive) && !flags.fetch(:output_only)
    puts "Would you like to #{action} the following command? [y(es),n(o)]"
    puts cmd_line
    ans = $stdin.gets().strip
    if ans !~ /y(es)?/i # treat as no
      exit 0
    end
  end
  if flags.fetch(:output_only) || !flags.fetch(:interactive)
    puts cmd_line
  end
  copy!(cmd_line, flags) if flags.fetch(:copy_to_clipboard)
  exit 0 if flags.fetch(:output_only) || flags.fetch(:copy_to_clipboard)
  begin
    exec cmd, *new_argv
  rescue SystemCallError => e
    if e.class == Errno::ENOENT
      # act like a shell
      $stderr.puts "#{cmd}: command not found"
    else
      $stderr.puts "#{e.class}: #{e.message}"
    end
    exit e.errno
  end
end

exec_cmd(new_argv, prev_pat, num_replacements, flags)

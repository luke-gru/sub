#!/usr/bin/env ruby
# frozen_string_literal: true

FLAGS = [
  { flag: 'f', name: :first_match, desc: "Substitute first matching word only.",
    example: "sub wget https://wget.com -- wget/curl/f #=> curl https://wget.com",
  },
  { flag: 'l', name: :last_match, desc: "Substitute last matching word only",
    example: "sub ls -al -- l//l #=> ls -a",
  },
  { flag: 'L', name: :literal, desc: "Interpret wildcards in pattern as literals",
    example: "sub cp here.txt there.txt -- ./_/L #=> cp here_txt there_txt",
  },
  { flag: 'i', name: :ignorecase, desc: "Set pattern to ignore the case of the match",
    example: "sub cp here.txt there.txt -- CP/mv/i #=> mv here.txt there.txt",
  },
  { flag: 'g', name: :general, desc: "General substitution: substitute all matches in every word",
    example: "sub cp here.txt there.txt -- ./_/g #=> __ ________ _________",
  },
  { flag: 'e', name: :expand_star, desc: "Expand star in commandline after replacements are made",
    example: [ "sub ls '*' -- //e #=> ls bin README",
               "sub ls hi -- hi/*/e #=> ls bin README", ]
  },
  { flag: 'I', name: :interactive, desc: "Set interactive mode, where it shows the command and prompts you" },
  { flag: 'o', name: :output_only, desc: "Print the command instead of executing it" },
  { flag: 'c', name: :copy_to_clipboard, desc: "Copy the command to clipboard instead of executing it" },
  { flag: 'v', name: :verbose, desc: "Set verbose mode" },
  { flag: 'D', name: :debug, desc: "Set debug mode" },
]

def print_help
  output = String.new
  FLAGS.each do |fhash|
    output << "-#{fhash[:flag]}:\t#{fhash[:desc]}\n"
    if ex = fhash[:example]
      case ex
      when String
        output << "  \t  ex: #{ex}\n"
      when Array
        ex.each do |x|
          output << "  \t  ex: #{x}\n"
        end
      end
    end
  end
  $stdout.puts output
end

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
    if cmd == "--help" || cmd == "-h"
      print_help
      exit 0
    end
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

def flag_by_name(name)
  FLAGS.each do |fhash|
    if fhash[:name] == name
      return fhash[:flag]
    end
  end
  nil
end

def parse_sub_str(sub_str)
  prev, new, flags = sub_str.split('/')
  prev = prev.to_s.dup
  new = new.to_s.dup
  flags = flags.to_s.dup
  flags.strip!
  flags_hash = {
    first_match: flag(flags, flag_by_name(:first_match)),
    last_match: flag(flags, flag_by_name(:last_match)),
    expand_star: flag(flags, flag_by_name(:expand_star)),
    literal: flag(flags, flag_by_name(:literal)),
    ignorecase: flag(flags, flag_by_name(:ignorecase)),
    general: flag(flags, flag_by_name(:general)),
    interactive: flag(flags, flag_by_name(:interactive)) || ARGV.size == 0,
    output_only: flag(flags, flag_by_name(:output_only)),
    copy_to_clipboard: flag(flags, flag_by_name(:copy_to_clipboard)),
    verbose: flag(flags, flag_by_name(:verbose)),
    debug: flag(flags, flag_by_name(:debug)),
  }
  prev.strip!
  new.strip!

  unless flags.empty?
    $stderr.puts "Warning: unknown flag#{'s' if flags.size != 1}: #{flags}"
  end

  [prev, new, flags_hash]
end

prev, new, flags = parse_sub_str(sub_str)

if prev.empty? && flags.empty?
  $stderr.puts "Incorrect substitution, format is: matching_pattern/new_text[/options]"
  exit 1
end

def build_regexp(literal, flags)
  regexp_opts = String.new
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
      if flags.fetch(:general)
        new_arg = arg.gsub(prev_pat, new)
        scan_size = arg.scan(prev_pat).size
      else
        new_arg = arg.sub(prev_pat, new)
        scan_size = arg.scan(prev_pat).size
        scan_size = 1 if scan_size > 1
      end
      if flags.fetch(:verbose) && (new_arg != arg || new_arg == new) && !flags.fetch(:last_match)
        num_replacements += scan_size
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
      if arg == '*' # ls '*' => ls bin README
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
  elsif /darwin/i =~ RUBY_PLATFORM
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
    $stdout.puts "Would you like to #{action} the following command? [y(es),n(o)]"
    $stdout.puts cmd_line
    ans = $stdin.gets().strip
    if ans !~ /y(es)?/i # treat as no
      exit 0
    end
  end
  if flags.fetch(:output_only) || !flags.fetch(:interactive)
    $stdout.puts cmd_line
    $stdout.flush
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

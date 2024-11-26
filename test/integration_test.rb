require "minitest/autorun"
require "debug"
require 'open3'

class IntegrationTest < Minitest::Test
  SUB_BIN = File.expand_path("#{__dir__}/../bin/sub")
  ENV["TESTING_SUB_CMD"] = "1"

  def test_sub_print_only
    out, err, code = run_sub(["ls", "-al"], "l//p")
    assert_equal "s -a\n", out
    assert_equal "", err
    assert_success code
  end

  def test_sub_print_only_no_newline
    out, err, code = run_sub(["ls", "-al"], "l//P")
    assert_equal "s -a", out
    assert_equal "", err
    assert_success code
  end

  def test_sub_invalid_option_gives_warning
    out, err, code = run_sub(["ls", "-al"], "l//pX")
    assert_equal "s -a\n", out
    assert_match(/Warning: unknown flag: X\n/, err)
    assert_success code
  end

  def test_sub_repeated_option_gives_no_warning
    out, err, code = run_sub(["ls",  "-al"], "l//pp")
    assert_equal "s -a\n", out
    assert_equal "", err
    assert_success code
  end

  def test_sub_command_doesnt_exist
    out, err, code = run_sub(["ls",  "-al"], "l/xxx/")
    assert_equal "xxxs -axxx\n", out
    assert_equal("xxxs: command not found\n", err)
    refute_success code
  end

  def test_sub_first_matching_word_only_f_option
    out, err, code = run_sub(["wget", "https://wget.com"], "wget/curl/fp")
    assert_equal "curl https://wget.com\n", out
    assert_equal "", err
    assert_success code
  end

  def test_sub_last_matching_word_only_l_option
    out, err, code = run_sub(["ls", "-al"], "l//l")
    expected = `ls -a`
    assert_equal("ls -a\n" + expected, out)
    assert_equal "", err
    assert_success code
  end

  def test_sub_interpret_wildcards_in_pattern_as_literals_L_option
    out, err, code = run_sub(["cp", "here.txt", "there.txt"], "./_/Lp")
    assert_equal("cp here_txt there_txt\n", out)
    assert_equal "", err
    assert_success code
  end

  def test_sub_pattern_ignorecase_i_option
    out, err, code = run_sub(["cp", "here.txt", "there.txt"], "CP/mv/ip")
    assert_equal("mv here.txt there.txt\n", out)
    assert_equal "", err
    assert_success code
  end

  def test_sub_general_substitution_g_option
    out, err, code = run_sub(["cp", "here.txt", "there.txt"], "./_/gp")
    assert_equal("__ ________ _________\n", out)
    assert_equal "", err
    assert_success code
  end

  def test_two_substitutions_without_interference
    out, err, code = run_sub(["ls", "-al"], "l//", "s//p")
    assert_match(/-a\s*?\n/, out)
    assert_equal "", err
    assert_success code
  end

  def test_multiple_substitutions_run_one_after_another
    out, err, code = run_sub(["ls", "-al"], "l/HI/", "hi/HEY/ip")
    assert_equal("HEYs -aHEY\n", out)
    assert_equal "", err
    assert_success code
  end

  def test_global_options_can_be_given_after_substitutions
    out, err, code = run_sub(["ls", "-al"], "l//", "/p")
    assert_equal("s -a\n", out)
    assert_equal "", err
    assert_success code
  end

  def test_patterns_can_escape_backslash
    # sub ls / -- '\//hi /p'
    out, err, code = run_sub(["ls", "/"], "\\//hi", "/p")
    assert_equal "", err
    assert_success code
    assert_equal("ls hi\n", out)
  end

  def test_pattern_can_match_space_character
    # sub ls '-al ' -- ' /hi' /p
    out, err, code = run_sub(["ls", "-al "], " /hi/", "/p")
    assert_equal "", err
    assert_success code
    assert_equal("ls -alhi\n", out)
  end

  def test_can_have_space_character_in_substitution
    # sub ls -al -- 'a/ ' /p
    out, err, code = run_sub(["ls", "-al"], "a/ ", "/p")
    assert_equal "", err
    assert_success code
    assert_equal("ls - l\n", out)
  end

  def test_copies_command_to_system_clipboard_c_option
    skip "no clipboard to test" unless can_paste_clipboard?
    change_system_clipboard do
      out, err, code = run_sub(["ls", "-al"], "/c")
      assert_equal "", err
      assert_success code
      assert_equal("ls -al\nCopied\n", out)
      assert_equal "ls -al", paste_clipboard
    end
  end

  def test_backreferences_work_with_groupings
    # sub ls -al -- '(l)/hi\1hi/p'
    out, err, code = run_sub(["ls", "-al"], "(l)/hi\\1hi/p")
    assert_equal "", err
    assert_success code
    assert_equal("hilhis -ahilhi\n", out)
  end

  def test_command_with_double_dash_still_works
    # sub ls -al -- dir -- -al/-a/p
    out, err, code = run_sub(["ls", "-al", "--", "dir"], "-al/-a/p")
    assert_equal "", err
    assert_success code
    assert_equal("ls -a -- dir\n", out)
  end

  INTERACTIVE_PROMPT = <<EOF
Would you like to execute the following command? [y(es),n(o)]
EOF

  def test_interactive_mode_dont_execute
    code = run_sub(["ls", "-al"], "-al/-a/I") do |stdin, stdout, _stderr|
      assert_equal INTERACTIVE_PROMPT + "ls -a\n", read_from_subprocess_io(stdout)
      stdin.puts "no"
    end
    assert_equal 1, code
  end

  def test_interactive_mode_execute
    code = run_sub(["ls", "-al"], "-al/-a/I") do |stdin, stdout, _stderr|
      assert_equal INTERACTIVE_PROMPT + "ls -a\n", read_from_subprocess_io(stdout)
      stdin.puts "y"
      assert_equal `ls -a`, read_from_subprocess_io(stdout)
    end
    assert_equal 0, code
  end

  private

  if ENV['DEBUGGING_SUB_CMD'] == '1'
    # enable debugger to work in subprocess
    def run_sub(cmdline_argv, *subs)
      args = cmdline_argv.dup
      args << "--"
      subs.each do |sub|
        args << sub
      end
      cmd = "#{SUB_BIN} #{args.join(' ')}"
      pid = fork do
        exec cmd, out: :out, err: :err, in: :in
      end
      if block_given?
        yield $stdin, $stdout, $stderr
        Process.waitpid(pid)
        $?.exitstatus
      else
        Process.waitpid(pid)
        status = $?.exitstatus
        ["", "", status]
      end
    end
  else
    def run_sub(cmdline_argv, *subs)
      args = cmdline_argv.dup
      args << "--"
      subs.each do |sub|
        args << sub
      end
      stdin, stdout, stderr, wait_thr = Open3.popen3(SUB_BIN, *args)
      if block_given?
        yield stdin, stdout, stderr
        return wait_thr.value.exitstatus
      end
      out = stdout.read
      err = stderr.read
      stderr.close
      stdin.close
      stdout.close
      exit_code = wait_thr.value.exitstatus
      [out, err, exit_code]
    end
  end

  def assert_success code
    assert_equal 0, code
  end

  def refute_success code
    refute_equal 0, code
  end

  def can_paste_clipboard?
    if RUBY_PLATFORM =~ /darwin/i
      system("which pbpaste > /dev/null 2>&1")
      $?.exitstatus == 0
    elsif RUBY_PLATFORM =~ /linux/i
      system("which xclip > /dev/null 2>&1")
      $?.exitstatus == 0
    end
  end

  def paste_clipboard
    if RUBY_PLATFORM =~ /darwin/i
      `pbpaste`
    elsif RUBY_PLATFORM =~ /linux/i
      `xclip -o -selection clipboard`
    end
  end

  def set_clipboard(contents)
    Tempfile.create("clipboard") do |f|
      f.write contents
      f.flush
      if RUBY_PLATFORM =~ /darwin/i
        system("cat #{f.path} | pbcopy")
      elsif RUBY_PLATFORM =~ /linux/i
        system("xclip -selection clipboard < #{f.path}")
      end
    end
  end

  def change_system_clipboard
    old_clipboard = paste_clipboard
    yield # changes clipboard
  ensure
    set_clipboard(old_clipboard)
  end

  def read_from_subprocess_io(io, max: 1024, max_retries: 100)
    begin
      io.read_nonblock(max)
    rescue IO::EAGAINWaitReadable # Would block. if using popen3 it could mean the thread hasn't run
      sleep 0.01
      max_retries -= 1
      if max_retries > 0
        retry
      else
        raise
      end
    end
  end
end

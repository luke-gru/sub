require "minitest/autorun"
require "debug"
require 'open3'

class IntegrationTest < Minitest::Test
  SUB_BIN = "./bin/sub"

  def test_sub_output_only
    out, err, code = run_sub("ls -al", "l//o")
    assert_equal "s -a\n", out
    assert_equal "", err
    assert_success code
  end

  def test_sub_invalid_option_gives_warning
    out, err, code = run_sub("ls -al", "l//oX")
    assert_equal "s -a\n", out
    assert_match /Warning: unknown flag: X\n/, err
    assert_success code
  end

  def test_sub_repeated_option_gives_no_warning
    out, err, code = run_sub("ls -al", "l//oo")
    assert_equal "s -a\n", out
    assert_equal "", err
    assert_success code
  end

  def test_sub_command_doesnt_exist
    out, err, code = run_sub("ls -al", "l/xxx/")
    assert_equal "xxxs -axxx\n", out
    assert_match(/xxxs: command not found/, err)
    refute_success code
  end

  def test_sub_first_matching_word_only_f_option
    out, err, code = run_sub("wget https://wget.com", "wget/curl/fo")
    assert_equal "curl https://wget.com\n", out
    assert_equal "", err
    assert_success code
  end

  def test_sub_last_matching_word_only_l_option
    out, err, code = run_sub("ls -al", "l//l")
    assert_match(/ls -a\n/, out)
    assert_equal "", err
    assert_success code
  end

  def test_sub_interpret_wildcards_in_pattern_as_literals_L_option
    out, err, code = run_sub("cp here.txt there.txt", "./_/Lo")
    assert_match(/cp here_txt there_txt\n/, out)
    assert_equal "", err
    assert_success code
  end

  def test_sub_pattern_ignorecase_i_option
    out, err, code = run_sub("cp here.txt there.txt", "CP/mv/io")
    assert_match(/mv here.txt there.txt\n/, out)
    assert_equal "", err
    assert_success code
  end

  def test_sub_general_substitution_g_option
    out, err, code = run_sub("cp here.txt there.txt", "./_/go")
    assert_match(/__ ________ _________\n/, out)
    assert_equal "", err
    assert_success code
  end

  private

  def run_sub(cmdline, sub)
    args = cmdline.split(/\s+/)
    args << "--"
    args << sub
    stdin, stdout, stderr, wait_thr = Open3.popen3(SUB_BIN, *args)
    if block_given?
      yield stdin, stdout, stderr
      return wait_thr.value
    end
    out = stdout.read
    stdout.close
    err = stderr.read
    stderr.close
    stdin.close
    exit_code = wait_thr.value
    [out, err, exit_code]
  end

  def assert_success code
    assert_equal 0, code
  end

  def refute_success code
    refute_equal 0, code
  end
end

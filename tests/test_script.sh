# test functions should start with test_

root_folder=$(git rev-parse --show-toplevel)
root_script=$(ls -S "$root_folder"/*.sh | head -1) # take largest .sh (in case there are smaller helper .sh scripts present)

test_should_show_option_verbose() {
  # script without parameters should give usage info
  assert_equals 1 "$("$root_script" 2>&1 | grep -c "verbose")"
}

test_simple_seconds_progress() {
  # simple progressbar for 3 seconds
  assert_equals 3 "$("$root_script" seconds 2 | grep -c "secs")"
}

test_memorisation() {
  # simple progressbar for 3 seconds
  uniq="test.$$"
  "$root_script" seconds 3 | "$root_script" -q lines "$uniq"
  assert_equals 5 "$("$root_script" check "$uniq" | grep "lines:" | gawk -F: '{print $2+0}')"
  assert_equals 6 "$("$root_script" seconds 3 | "$root_script" lines "$uniq" | grep -c "secs")"
}

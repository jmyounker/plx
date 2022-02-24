#!/usr/bin/env bats

source ./plx import >&3

tmpdir() {
    td="$BATS_TEST_TMPDIR/$RANDOM"
    mkdir "$td"
    echo -n "$td"
}

create_test_command() {
    while [ $# -gt 0 ]; do
        install -m 755 tests/fixture-program "$1"
        shift
    done
}

create_vertex_shell() {
    while [ $# -gt 0 ]; do
        install -m 755 tests/fixture-vertex-shell "$1"
        shift
    done
}


@test "True if option starts with dash" {
    option_starts_with_dash -foo
}

@test "False if option starts does not start with dash" {
    ! option_starts_with_dash foo
}


@test "Test cache file generation ignores the root" {
  td=$(tmpdir)
  cache_file="$td/cache.txt"
  create_test_command "$td/root-sub"
  create_test_command "$td/root-sub-x"
  cache_subcommands root-sub "$td" "$cache_file"
  diff -q "$cache_file" <(cat <<EXPECTED
x $td/root-sub-x
EXPECTED
)
}

@test "Test cache file generation on directory" {
  td=$(tmpdir)
  cache_file="$td/cache.txt"
  create_test_command "$td/root-x"
  create_test_command "$td/root-y"
  cache_subcommands root "$td" "$cache_file"
  diff -q "$cache_file" <(cat <<EXPECTED
x $td/root-x
y $td/root-y
EXPECTED
)
}

@test "Test cache file generation ignores deeper subcommands" {
  td=$(tmpdir)
  cache_file="$td/cache.txt"
  create_vertex_shell "$td/root-x"
  create_test_command "$td/root-x-y"
  cache_subcommands root "$td" "$cache_file"
  diff -q "$cache_file" <(cat <<EXPECTED
x $td/root-x
EXPECTED
)
}

@test "Test cache file generation crosses directories" {
  td1=$(tmpdir)
  td2=$(tmpdir)
  cache_file="$td1/cache.txt"
  create_test_command "$td1/root-x"
  create_test_command "$td2/root-y"
  cache_subcommands root "$td1:$td2" "$cache_file"
  diff -q "$cache_file" <(cat <<EXPECTED
x $td1/root-x
y $td2/root-y
EXPECTED
)
}

@test "Test cache file generation skips duplicates" {
  td1=$(tmpdir)
  td2=$(tmpdir)
  cache_file="$BATS_TEST_TMPDIR/cache.txt"
  create_test_command "$td1/root-x"
  create_test_command "$td2/root-x"
  cache_subcommands root "$td1:$td2" "$cache_file"
  diff "$cache_file" <(cat <<EXPECTED
x $td1/root-x
EXPECTED
)
}

@test "Execute defaults with no arguments" {
  td=$(tmpdir)
  create_vertex_shell "$td/root"
  create_test_command "$td/root-x"
  create_test_command "$td/root-default"
  run "$td/root" -name
  [ "${lines[0]}" == 'run-default' ]
}

#!/bin/zsh

set -euo pipefail

repo_root="${0:A:h:h:h}"
importer="$repo_root/zsh/import-zoxide-history.zsh"
tmpdir="$(mktemp -d)"
tmpdir="${tmpdir:A}"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/bin" "$tmpdir/projects/Hermes" "$tmpdir/projects/Zenith Commander"

cat > "$tmpdir/bin/zoxide" <<'FAKE_ZOXIDE'
#!/bin/zsh
[[ "$1" == "add" ]] || exit 64
print -r -- "$2" >> "$ZOXIDE_TEST_LOG"
FAKE_ZOXIDE
chmod +x "$tmpdir/bin/zoxide"

history_file="$tmpdir/history"
cat > "$history_file" <<EOF
: 1710000000:0;cd $tmpdir/projects/Hermes
: 1710000001:0;cd "$tmpdir/projects/Zenith Commander"
: 1710000002:0;cd $tmpdir/projects/Hermes
cd relative-project
cd -
cd '\$(touch $tmpdir/should-not-exist)'
echo cd $tmpdir/projects/Hermes
EOF

export PATH="$tmpdir/bin:$PATH"
export ZOXIDE_TEST_LOG="$tmpdir/zoxide.log"

output="$("$importer" "$history_file")"

expected="$(cat <<EOF
$tmpdir/projects/Hermes
$tmpdir/projects/Zenith Commander
$tmpdir/projects/Hermes
EOF
)"
actual="$(<"$ZOXIDE_TEST_LOG")"

[[ "$actual" == "$expected" ]] || {
  print -u2 -- "unexpected imported paths"
  diff -u <(print -r -- "$expected") <(print -r -- "$actual")
  exit 1
}

[[ ! -e "$tmpdir/should-not-exist" ]] || {
  print -u2 -- "history content was executed"
  exit 1
}

[[ "$output" == *"Imported 3 history entries (2 unique directories)."* ]] || {
  print -u2 -- "unexpected summary: $output"
  exit 1
}

print -- "PASS: import-zoxide-history"

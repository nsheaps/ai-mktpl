# Claude Tools - TODO

## worktree-switcher: Use shell function instead of exec

Currently `worktree-switcher` uses `exec $SHELL` to launch a new shell in the worktree directory. This has downsides:

- Creates nested shells if used repeatedly
- May lose environment state
- Feels "heavy"

**Better approach:** Provide a shell function that users source into their shell config:

```bash
# In ~/.bashrc or ~/.zshrc
wts() {
  local path
  path="$(worktree-switcher --print-path "$@")" || return $?
  cd "$path"
}
```

This would require:

1. Add `--print-path` flag that outputs just the path (no messages)
2. Document the shell function in README
3. Optionally provide an install script that adds the function to user's shell config

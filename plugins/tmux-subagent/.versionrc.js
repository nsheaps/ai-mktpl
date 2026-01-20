module.exports = {
  releaseCommitMessageFormat: "chore(tmux-subagent): release {{currentTag}}",
  skip: {
    bump: false,
    changelog: false,
    commit: false,
    tag: true,
  },
  tagPrefix: "tmux-subagent@",
  packageFiles: [
    {
      filename: ".claude-plugin/plugin.json",
      type: "json",
    },
  ],
  bumpFiles: [
    {
      filename: ".claude-plugin/plugin.json",
      type: "json",
    },
  ],
};

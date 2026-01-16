module.exports = {
  releaseCommitMessageFormat: "chore(statusline): release {{currentTag}}",
  scripts: {
    postbump: "prettier --write .claude-plugin/plugin.json",
  },
  skip: {
    bump: false,
    changelog: false,
    commit: false,
    tag: true,
  },
  tagPrefix: "statusline@",
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

module.exports = {
  releaseCommitMessageFormat: "chore(create-command): release {{currentTag}}",
  scripts: {
    postbump: "prettier --write .claude-plugin/plugin.json",
  },
  skip: {
    bump: false,
    changelog: false,
    commit: false,
    tag: true,
  },
  tagPrefix: "create-command@",
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

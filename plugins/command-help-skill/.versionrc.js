module.exports = {
  releaseCommitMessageFormat: "chore(command-help-skill): release {{currentTag}}",
  skip: {
    bump: false,
    changelog: false,
    commit: false,
    tag: true,
  },
  tagPrefix: "command-help-skill@",
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

module.exports = {
  releaseCommitMessageFormat: "chore(sync-settings): release {{currentTag}}",
  skip: {
    bump: false,
    changelog: false,
    commit: false,
    tag: true,
  },
  tagPrefix: "sync-settings@",
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

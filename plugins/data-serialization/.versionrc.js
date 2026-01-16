module.exports = {
  releaseCommitMessageFormat: "chore(data-serialization): release {{currentTag}}",
  scripts: {
    postbump: "prettier --write .claude-plugin/plugin.json",
  },
  skip: {
    bump: false,
    changelog: false,
    commit: false,
    tag: true,
  },
  tagPrefix: "data-serialization@",
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

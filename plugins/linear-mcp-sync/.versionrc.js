module.exports = {
  releaseCommitMessageFormat: "chore(release): {{currentTag}} [skip ci]",
  scripts: {},
  skip: {
    bump: false,
    changelog: false,
    commit: false,
    tag: false,
  },
  tagPrefix: "linear-mcp-sync@",
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

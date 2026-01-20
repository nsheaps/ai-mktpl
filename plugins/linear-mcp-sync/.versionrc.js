module.exports = {
  releaseCommitMessageFormat: "chore(linear-mcp-sync): release {{currentTag}}",
  skip: {
    bump: false,
    changelog: false,
    commit: false,
    tag: true,
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

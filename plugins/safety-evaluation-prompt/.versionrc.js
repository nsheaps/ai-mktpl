module.exports = {
  releaseCommitMessageFormat: "chore(safety-evaluation-prompt): release {{currentTag}}",
  scripts: {
    postbump: "prettier --write .claude-plugin/plugin.json",
  },
  skip: {
    bump: false,
    changelog: false,
    commit: false,
    tag: true,
  },
  tagPrefix: "safety-evaluation-prompt@",
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

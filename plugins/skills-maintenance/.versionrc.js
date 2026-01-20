module.exports = {
  releaseCommitMessageFormat: "chore(skills-maintenance): release {{currentTag}}",
  skip: {
    bump: false,
    changelog: false,
    commit: false,
    tag: true,
  },
  tagPrefix: "skills-maintenance@",
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

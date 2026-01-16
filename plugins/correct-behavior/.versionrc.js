module.exports = {
  scripts: {},
  skip: {
    bump: false,
    changelog: false,
    commit: false,
    tag: false,
  },
  tagPrefix: "correct-behavior@",
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

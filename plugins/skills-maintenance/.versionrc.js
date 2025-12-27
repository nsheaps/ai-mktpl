module.exports = {
  // https://github.com/absolute-version/commit-and-tag-version?tab=readme-ov-file#lifecycle-scripts
  scripts: {},
  skip: {
    bump: false,
    changelog: false,
    commit: false,
    // monorepo...tags would be terrible, and root marketplace wouldn't be helpful
    tag: true,
  },
  packageFiles: [
    {
      filename: ".claude-plugin/plugin.json",
      // The `json` updater assumes the version is available under a `version` key in the provided JSON document.
      type: "json",
    },
  ],
  bumpFiles: [
    {
      filename: ".claude-plugin/plugin.json",
      // The `json` updater assumes the version is available under a `version` key in the provided JSON document.
      type: "json",
    },
  ],
};

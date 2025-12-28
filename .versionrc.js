module.exports = {
  // https://github.com/absolute-version/commit-and-tag-version?tab=readme-ov-file#lifecycle-scripts
  scripts: {
    prerelease: "",
    // the marketplace file gets updated constantly, so no versioning for the root .claude-plugin
    // prebump: "echo 0.0.0",
    // postbump: "",
    prechangelog: "",
    postchangelog: "",
    precommit: "",
    postcommit: "",
    pretag: "",
    posttag: "",
  },
  skip: {
    bump: true,
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
};

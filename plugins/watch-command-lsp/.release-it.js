module.exports = {
  extends: "../../.release-it.base.json",
  plugins: {
    "@release-it/bumper": {
      in: ".claude-plugin/plugin.json",
      out: ".claude-plugin/plugin.json",
    },
  },
};

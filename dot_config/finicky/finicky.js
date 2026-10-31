const discordApp = {
  name: "com.gnohj.discord-link",
  appType: "bundleId",
};

export default {
  defaultBrowser: { name: "Helium", profile: "personal" },
  options: {
    checkForUpdates: false,
  },
  handlers: [
    {
      match: ["discord.com/channels/*", "discord.gg/*"],
      browser: discordApp,
    },
    {
      match: ["*.atlassian.net/*", "github.com/iheartradio/*", "*.ts.net/*"],
      browser: { name: "Helium", profile: "Work" },
    },
  ],
};

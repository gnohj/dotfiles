const discordApp = {
  name: "com.gnohj.discord-link",
  appType: "bundleId",
};

const teamsApp = {
  name: "com.gnohj.msteams-handler",
  appType: "bundleId",
};

const outlookApp = {
  name: "com.gnohj.outlook-link",
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
      match: ["teams.microsoft.com/*", "teams.cloud.microsoft/*"],
      browser: teamsApp,
    },
    {
      match: [
        "outlook.office.com/*",
        "outlook.office365.com/*",
        "outlook.cloud.microsoft/*",
      ],
      browser: outlookApp,
    },
    {
      match: [
        "*.atlassian.net/*",
        "github.com/iheartradio/*",
        "*.ts.net/*",
        "*.safelinks.protection.outlook.com/*",
        "iheartmedia.sharepoint.com/*",
        "*teams.microsoft.com/*",
      ],
      browser: { name: "Helium", profile: "Work" },
    },
  ],
};

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

const slackApp = {
  name: "com.gnohj.slack-link",
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
      match: ["*.slack.com/archives/*", "app.slack.com/client/*"],
      browser: slackApp,
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
        "*.iheart.com/*",
        "*.internal.example.com/*",
        "*.ts.net/*",
        "*.ts.net:*",
        "*.safelinks.protection.outlook.com/*",
        "iheartmedia.sharepoint.com/*",
        "*teams.microsoft.com/*",
      ],
      browser: { name: "Helium", profile: "Work" },
    },
  ],
};

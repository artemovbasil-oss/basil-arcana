import { createInterface } from "node:readline/promises";
import { mkdir } from "node:fs/promises";
import path from "node:path";
import { stdin as input, stdout as output } from "node:process";

import { TelegramClient } from "telegram";
import { StringSession } from "telegram/sessions";
import QRCode from "qrcode";

const qrcode = require("qrcode-terminal") as {
  generate: (value: string, options?: { small?: boolean }) => void;
};

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value || value.trim().length === 0) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

async function main(): Promise<void> {
  const apiId = Number(requireEnv("TELEGRAM_API_ID"));
  const apiHash = requireEnv("TELEGRAM_API_HASH");
  if (!Number.isFinite(apiId)) {
    throw new Error("TELEGRAM_API_ID must be a number");
  }

  const rl = createInterface({ input, output });
  const client = new TelegramClient(new StringSession(""), apiId, apiHash, {
    connectionRetries: 5,
  });

  try {
    await client.connect();

    const preferredMode = (process.env.SOFIA_SESSION_LOGIN_MODE ?? "").trim().toLowerCase();
    const mode =
      preferredMode === "qr" || preferredMode === "phone"
        ? preferredMode
        : (await rl.question("Login mode ([qr]/phone): ")).trim().toLowerCase() || "qr";

    if (mode === "phone") {
      await client.start({
        phoneNumber: async () => rl.question("Telegram phone number (international format): "),
        phoneCode: async () => rl.question("Login code from Telegram: "),
        password: async () => rl.question("2FA password (if enabled, otherwise press Enter): "),
        onError: async (error) => {
          output.write(`Authorization error: ${error.message}\n`);
          return false;
        },
      });
    } else {
      output.write(
        "\nOpen Telegram on a device where Sofia is already logged in:\nSettings -> Devices -> Link Desktop Device, then scan the QR below.\n\n",
      );
      await client.signInUserWithQrCode(
        { apiId, apiHash },
        {
          password: async () => rl.question("2FA password (if enabled, otherwise press Enter): "),
          qrCode: async (code) => {
            const url = `tg://login?token=${code.token.toString("base64url")}`;
            const qrDir = path.join(process.cwd(), ".tmp");
            const qrPath = path.join(qrDir, "sofia-login-qr.png");
            await mkdir(qrDir, { recursive: true });
            await QRCode.toFile(qrPath, url, {
              errorCorrectionLevel: "M",
              margin: 2,
              scale: 8,
            });
            qrcode.generate(url, { small: true });
            output.write(`QR image saved to: ${qrPath}\n`);
            output.write(`QR expires at: ${new Date(code.expires * 1000).toISOString()}\n\n`);
          },
          onError: async (error) => {
            output.write(`QR login error: ${error.message}\n`);
            return false;
          },
        },
      );
    }

    const sessionString = client.session.save();
    const me = await client.getMe();
    output.write("\nTelegram session created successfully.\n");
    output.write(
      `Authorized as: ${[me.firstName, me.lastName].filter(Boolean).join(" ") || "unknown"} ${me.username ? `(@${me.username})` : ""}\n`,
    );
    output.write(`\nSOFIA_SESSION_STRING=${sessionString}\n`);
  } finally {
    rl.close();
    await client.disconnect();
  }
}

main().catch((error) => {
  process.stderr.write(`${error instanceof Error ? error.stack ?? error.message : String(error)}\n`);
  process.exitCode = 1;
});

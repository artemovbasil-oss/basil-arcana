"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const promises_1 = require("node:readline/promises");
const node_process_1 = require("node:process");
const telegram_1 = require("telegram");
const sessions_1 = require("telegram/sessions");
const qrcode = require("qrcode-terminal");
function requireEnv(name) {
    const value = process.env[name];
    if (!value || value.trim().length === 0) {
        throw new Error(`Missing required environment variable: ${name}`);
    }
    return value;
}
async function main() {
    const apiId = Number(requireEnv("TELEGRAM_API_ID"));
    const apiHash = requireEnv("TELEGRAM_API_HASH");
    if (!Number.isFinite(apiId)) {
        throw new Error("TELEGRAM_API_ID must be a number");
    }
    const rl = (0, promises_1.createInterface)({ input: node_process_1.stdin, output: node_process_1.stdout });
    const client = new telegram_1.TelegramClient(new sessions_1.StringSession(""), apiId, apiHash, {
        connectionRetries: 5,
    });
    try {
        const preferredMode = (process.env.SOFIA_SESSION_LOGIN_MODE ?? "").trim().toLowerCase();
        const mode = preferredMode === "qr" || preferredMode === "phone"
            ? preferredMode
            : (await rl.question("Login mode ([qr]/phone): ")).trim().toLowerCase() || "qr";
        if (mode === "phone") {
            await client.start({
                phoneNumber: async () => rl.question("Telegram phone number (international format): "),
                phoneCode: async () => rl.question("Login code from Telegram: "),
                password: async () => rl.question("2FA password (if enabled, otherwise press Enter): "),
                onError: async (error) => {
                    node_process_1.stdout.write(`Authorization error: ${error.message}\n`);
                    return false;
                },
            });
        }
        else {
            node_process_1.stdout.write("\nOpen Telegram on a device where Sofia is already logged in:\nSettings -> Devices -> Link Desktop Device, then scan the QR below.\n\n");
            await client.signInUserWithQrCode({ apiId, apiHash }, {
                password: async () => rl.question("2FA password (if enabled, otherwise press Enter): "),
                qrCode: async (code) => {
                    const url = `tg://login?token=${code.token.toString("base64url")}`;
                    qrcode.generate(url, { small: true });
                    node_process_1.stdout.write(`QR expires at: ${new Date(code.expires * 1000).toISOString()}\n\n`);
                },
                onError: async (error) => {
                    node_process_1.stdout.write(`QR login error: ${error.message}\n`);
                    return false;
                },
            });
        }
        const sessionString = client.session.save();
        const me = await client.getMe();
        node_process_1.stdout.write("\nTelegram session created successfully.\n");
        node_process_1.stdout.write(`Authorized as: ${[me.firstName, me.lastName].filter(Boolean).join(" ") || "unknown"} ${me.username ? `(@${me.username})` : ""}\n`);
        node_process_1.stdout.write(`\nSOFIA_SESSION_STRING=${sessionString}\n`);
    }
    finally {
        rl.close();
        await client.disconnect();
    }
}
main().catch((error) => {
    process.stderr.write(`${error instanceof Error ? error.stack ?? error.message : String(error)}\n`);
    process.exitCode = 1;
});

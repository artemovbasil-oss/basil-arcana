import { test, expect } from "@playwright/test";

test.describe.configure({ mode: "serial" });

test.beforeEach(async ({ request }) => {
  await request.delete("/api/profile").catch(() => {});
});

test("login screen renders free tools entry points", async ({ page }) => {
  await page.goto("/login");
  await expect(page.getByRole("heading", { name: /sign in/i })).toBeVisible();
  const leadCards = page.locator(".login-lead-card");
  const count = await leadCards.count();
  if (count > 0) {
    await expect(page.getByRole("link", { name: /pair compatibility check/i })).toBeVisible();
    await expect(page.getByRole("link", { name: /best windows of today/i })).toBeVisible();
    await expect(page.getByRole("link", { name: /numerology quick read/i })).toBeVisible();
  } else {
    await expect(page.getByText(/no login providers configured yet/i)).toBeVisible();
  }
});

test("free timing windows calculates result", async ({ page }) => {
  await page.goto("/free-tools/timing-windows");
  await page.locator("input[name='birthDate']").fill("1983-10-26");
  await page.locator("input[name='birthCity']").fill("Istanbul, Turkey");
  await page.getByRole("button", { name: /calculate windows/i }).click();
  await expect(page.getByText(/best windows:/i)).toBeVisible();
  await expect(page.getByText(/energy index:/i)).toBeVisible();
});

test("onboarding -> friends referral -> delete profile", async ({ page }) => {
  await page.goto("/onboarding");
  await page.locator("input[name='name']").fill("E2E Test User");
  await page.locator("input[name='birthDate']").fill("1990-04-10");
  await page.locator("input[name='birthTime']").fill("10:30");
  await page.locator("input[name='birthCity']").fill("Paris, France");
  await page.locator(".onboarding-celeb-card").first().click();
  await page.getByRole("button", { name: /save and continue/i }).click();

  await expect(page).toHaveURL("/");
  const profilePayload = await page.request.get("/api/profile");
  await expect(profilePayload.ok()).toBeTruthy();
  const profileJson = await profilePayload.json();
  await expect(profileJson?.profile?.name).toBe("E2E Test User");

  await page.goto("/friends");
  const referralLink = page.locator("#referralLinkAnchor");
  await expect(referralLink).toBeVisible();
  await expect(referralLink).toHaveAttribute("href", /\/login\?ref=ASTRO-/);

  await page.goto("/profile");
  page.once("dialog", async (dialog) => {
    await dialog.accept();
  });
  await page.getByRole("button", { name: /delete profile forever/i }).click();
  await expect(page).toHaveURL("/login");
});

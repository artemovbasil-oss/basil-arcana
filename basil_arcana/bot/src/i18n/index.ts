import en from "./en";
import ru from "./ru";
import kk from "./kk";
import type { Locale } from "../config";

const translations = { en, ru, kk } as const;

export type Messages = typeof en;

export function t(locale: Locale): Messages {
  return translations[locale] || translations.en;
}

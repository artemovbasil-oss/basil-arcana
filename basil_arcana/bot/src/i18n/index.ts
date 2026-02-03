import en from "./en";
import ru from "./ru";
import kk from "./kk";
import type { Locale } from "../config";
import type { I18nStrings } from "./types";

export type I18nKey = keyof I18nStrings;
export type Dict = Record<I18nKey, string>;

const dicts: Record<Locale, I18nStrings> = { en, ru, kk };

export type Messages = I18nStrings;

export function t(locale: Locale): Messages {
  return dicts[locale] || dicts.en;
}

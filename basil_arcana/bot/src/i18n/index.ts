import en from "./en";
import ru from "./ru";
import kk from "./kk";
import type { Locale } from "../config";

export type I18nKey = keyof typeof en;
export type Dict = Record<I18nKey, string>;

const dicts: Record<Locale, Dict> = { en, ru, kk };

export type Messages = Dict;

export function t(locale: Locale): Messages {
  return dicts[locale] || dicts.en;
}

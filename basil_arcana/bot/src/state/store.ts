import type { Locale } from "../config";
import type { UserState } from "./types";

export class StateStore {
  private readonly states = new Map<number, UserState>();
  private readonly defaultLocale: Locale;

  constructor(defaultLocale: Locale) {
    this.defaultLocale = defaultLocale;
  }

  get(userId: number): UserState {
    const existing = this.states.get(userId);
    if (existing) {
      return existing;
    }
    const initial: UserState = {
      locale: this.defaultLocale,
      step: "idle",
      isProcessing: false,
    };
    this.states.set(userId, initial);
    return initial;
  }

  set(userId: number, state: UserState): void {
    this.states.set(userId, state);
  }

  update(userId: number, partial: Partial<UserState>): UserState {
    const current = this.get(userId);
    const next = { ...current, ...partial };
    this.states.set(userId, next);
    return next;
  }
}

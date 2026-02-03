"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.StateStore = void 0;
class StateStore {
    states = new Map();
    defaultLocale;
    constructor(defaultLocale) {
        this.defaultLocale = defaultLocale;
    }
    get(userId) {
        const existing = this.states.get(userId);
        if (existing) {
            return existing;
        }
        const initial = {
            locale: this.defaultLocale,
            step: "idle",
            isProcessing: false,
        };
        this.states.set(userId, initial);
        return initial;
    }
    set(userId, state) {
        this.states.set(userId, state);
    }
    update(userId, partial) {
        const current = this.get(userId);
        const next = { ...current, ...partial };
        this.states.set(userId, next);
        return next;
    }
}
exports.StateStore = StateStore;

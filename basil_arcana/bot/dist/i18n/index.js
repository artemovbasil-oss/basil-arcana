"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.t = t;
const en_1 = __importDefault(require("./en"));
const ru_1 = __importDefault(require("./ru"));
const kk_1 = __importDefault(require("./kk"));
const dicts = { en: en_1.default, ru: ru_1.default, kk: kk_1.default };
function t(locale) {
    return dicts[locale] || dicts.en;
}

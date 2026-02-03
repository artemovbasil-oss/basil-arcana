import type { Locale } from "../config";

export type FlowStep =
  | "idle"
  | "awaiting_question"
  | "awaiting_spread"
  | "showing_result";

export interface ReadingPayload {
  question: string;
  spread: Spread;
  cards: DrawnCard[];
}

export interface SpreadPosition {
  id: string;
  title: string;
}

export interface Spread {
  id: string;
  name: string;
  positions: SpreadPosition[];
}

export interface CardMeaning {
  general: string;
  light: string;
  shadow: string;
  advice: string;
}

export interface CardData {
  title: string;
  keywords: string[];
  meaning: CardMeaning;
}

export interface DrawnCard {
  positionId: string;
  positionTitle: string;
  cardId: string;
  cardName: string;
  keywords: string[];
  meaning: CardMeaning;
}

export interface UserState {
  locale: Locale;
  step: FlowStep;
  question?: string;
  spreadId?: "one" | "three";
  lastReading?: ReadingPayload;
  isProcessing: boolean;
}

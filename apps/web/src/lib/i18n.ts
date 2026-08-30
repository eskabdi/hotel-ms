import i18n from "i18next";
import { initReactI18next } from "react-i18next";
import en from "@/locales/en/common.json";
import am from "@/locales/am/common.json";

// D-11: English + Amharic, per-user language preference (default en for now —
// wiring the preference to users_profile.locale is a follow-up increment).
void i18n.use(initReactI18next).init({
  resources: {
    en: { common: en },
    am: { common: am },
  },
  lng: "en",
  fallbackLng: "en",
  defaultNS: "common",
  interpolation: { escapeValue: false },
});

export default i18n;

import js from "@eslint/js";
import tseslint from "typescript-eslint";
import react from "eslint-plugin-react";
import reactHooks from "eslint-plugin-react-hooks";
import reactRefresh from "eslint-plugin-react-refresh";
import globals from "globals";

export default tseslint.config(
  { ignores: ["dist"] },
  {
    extends: [js.configs.recommended, ...tseslint.configs.recommended],
    files: ["**/*.{ts,tsx}"],
    languageOptions: {
      ecmaVersion: 2022,
      globals: globals.browser,
    },
    plugins: {
      react,
      "react-hooks": reactHooks,
      "react-refresh": reactRefresh,
    },
    rules: {
      ...reactHooks.configs.recommended.rules,
      "react-refresh/only-export-components": ["warn", { allowConstantExport: true }],
      // D-22: no HTML injection anywhere in the client.
      "react/no-danger": "error",
      // D-23: the client never holds elevated credentials.
      "no-restricted-syntax": [
        "error",
        {
          selector: "Identifier[name='SUPABASE_SERVICE_ROLE_KEY']",
          message: "D-23: service-role key must never appear in client code.",
        },
        {
          selector: "Identifier[name='service_role']",
          message: "D-23: service-role key must never appear in client code.",
        },
      ],
    },
  }
);

import type { Config } from "tailwindcss";

// Token values per docs/engida-hms-master-blueprint-v1.md §34, palette swapped
// per plan decision: Z Shop palette in place of the blueprint's own indigo/gold.
// Source: docs/Z_Shop_UX_Design_Color_Palette.md
export default {
  darkMode: "class",
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: "#FF6800",
          hover: "#F05100",
          foreground: "#FFFFFF",
        },
        accent: {
          DEFAULT: "#FFB800",
          foreground: "#041009",
        },
        surface: {
          DEFAULT: "#FFFFFF",
          muted: "#F4F4F5",
        },
        border: "#E5E5E5",
        text: {
          primary: "#041009",
          secondary: "#737373",
          tertiary: "#3E3F46",
        },
        dark: {
          DEFAULT: "#18181B",
          foreground: "#D3D4D8",
        },
        success: "#00D294",
        warning: "#FFD134",
        danger: "#C90034",
        info: "#3080FF",
        status: {
          hold: "#FFD134",
          confirmed: "#3080FF",
          inhouse: "#00D294",
          checkedout: "#737373",
          cancelled: "#A1A1AA",
          noshow: "#C90034",
          ooo: "#C90034",
          oos: "#FFD134",
          dirty: "#C90034",
          clean: "#FFD134",
          inspected: "#00D294",
        },
      },
      fontFamily: {
        sans: ["Public Sans", "system-ui", "sans-serif"],
        numeric: ["Inter", "system-ui", "sans-serif"],
        ethiopic: ["Noto Sans Ethiopic", "Public Sans", "system-ui", "sans-serif"],
      },
      borderRadius: {
        DEFAULT: "0.5rem",
      },
    },
  },
  plugins: [],
} satisfies Config;

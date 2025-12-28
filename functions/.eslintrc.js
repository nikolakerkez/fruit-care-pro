module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
  ],
  rules: {
    "quotes": ["error", "double"],
  },
  parserOptions: {
    ecmaVersion: 2020,  // 🔥 Promeni sa 2018 na 2020 (podržava ?.)
    sourceType: "module",
  },
};
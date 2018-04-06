module.exports = {
    "plugins": [ "coffeescript", "node" ],
    // "parser": "eslint-plugin-coffeescript",
    "env": {
        "browser": true,
        "node": true,
        "commonjs": true,
        "es6": true
    },
    "parserOptions": {
        "ecmaVersion": 2017,
        "parser": "espree", // original parser goes here (you must specify one to use this option).
        "sourceType": "module", // any original parser config options you had.
        // "ecmaVersion": 6
    },
    "extends": ["eslint:recommended",  "plugin:node/recommended"],
    "rules": {
        "no-unused-vars": ["warn", { "vars": "all", "args": "after-used", "ignoreRestSiblings": false }],
        "node/no-missing-require": ["error", {
            "tryExtensions": [".js", ".json", ".node", ".coffee"]
        }],
        "no-constant-condition": ["warn", {"checkLoops": false}],
        "linebreak-style": [
            "error",
            "unix"
        ],
        "quotes": [
            "error",
            "single"
        ],
        "semi": [
            "error",
            "always"
        ],
        "no-console": "off"
    }
};

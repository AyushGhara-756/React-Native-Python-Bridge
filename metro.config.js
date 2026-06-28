const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');

const defaultConfig = getDefaultConfig(__dirname);

const config = {
  resolver: {
    blockList: [
      /\/python\//,
    ],
  },
};

module.exports = mergeConfig(defaultConfig, config);
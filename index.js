require('coffee-script/register');

module.exports = {
  build: require('./lib/build'),
  upload: require('./lib/upload')
};
